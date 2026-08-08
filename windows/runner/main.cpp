#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <cctype>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Names a per-user mutex so a second "Open with Atlas" launch can hand the
// document to the running instance instead of opening another window. Kept in
// the "Local\\" namespace so forwarding only applies within the same logon
// session (Windows Desktop apps cannot trade WM_COPYDATA across sessions).
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\Atlas.Book.1.Instance";

// The window class every Atlas top-level window is registered under. Must be
// kept in sync with kWindowClassName in win32_window.cpp.
constexpr const wchar_t kMainWindowClassName[] = L"AtlasMainWindow";

// Extensions the shell is allowed to hand Atlas. Mirror of
// FileOpenController._supportedFilePath.
const char* const kOpenedExtensions[] = {".epub", ".pdf", ".atlas"};

bool IsSupportedOpenPath(const std::string& path) {
  std::string lower = path;
  for (auto& c : lower) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  for (const char* ext : kOpenedExtensions) {
    const size_t ext_len = std::char_traits<char>::length(ext);
    if (lower.size() > ext_len &&
        lower.compare(lower.size() - ext_len, ext_len, ext) == 0) {
      return true;
    }
  }
  return false;
}

// Brings an already-running Atlas to the front and hands it the documents the
// shell asked us to open. Each path travels in its own WM_COPYDATA so the
// receiver can process it synchronously before this process exits.
void ForwardOpenedFiles(const std::vector<std::string>& paths) {
  HWND existing = FindWindowW(kMainWindowClassName, nullptr);
  if (existing == nullptr) {
    existing = FindWindowW(nullptr, L"Atlas");
  }
  if (existing == nullptr) {
    return;
  }
  if (IsIconic(existing)) {
    ShowWindow(existing, SW_RESTORE);
  }
  SetForegroundWindow(existing);
  for (const std::string& path : paths) {
    COPYDATASTRUCT cds{};
    cds.dwData = 0;
    cds.cbData = static_cast<DWORD>(path.size() + 1);
    cds.lpData = const_cast<char*>(path.c_str());
    SendMessageW(existing, WM_COPYDATA, reinterpret_cast<WPARAM>(existing),
                 reinterpret_cast<LPARAM>(&cds));
  }
}

// Registers .epub/.pdf/.atlas so the shell's "Open with Atlas" offers this app
// and launches it with the document path as a command-line argument (delivered
// to Dart via Platform.executableArguments). Keys live under HKCU, so no
// administrator rights are required, and launching never prompts.
void RegisterFileType(const std::wstring& extension, const std::wstring& prog_id,
                      const std::wstring& friendly_name) {
  HKEY key;
  std::wstring ext_path = L"Software\\Classes\\" + extension;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, ext_path.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) == ERROR_SUCCESS) {
    const BYTE* data = reinterpret_cast<const BYTE*>(prog_id.data());
    RegSetValueExW(key, nullptr, 0, REG_SZ, data,
                   static_cast<DWORD>((prog_id.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
  }

  std::wstring prog_path = L"Software\\Classes\\" + prog_id;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, prog_path.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) == ERROR_SUCCESS) {
    const BYTE* name = reinterpret_cast<const BYTE*>(friendly_name.c_str());
    RegSetValueExW(key, nullptr, 0, REG_SZ, name,
                   static_cast<DWORD>((friendly_name.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
  }
}

void RegisterOpenCommand(const std::wstring& prog_id, const std::wstring& exe_path) {
  const std::wstring command =
      L"\"" + exe_path + L"\" \"%1\"";
  std::wstring command_path =
      L"Software\\Classes\\" + prog_id + L"\\shell\\open\\command";
  HKEY key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, command_path.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) == ERROR_SUCCESS) {
    const std::wstring shell_command = command;
    const BYTE* data = reinterpret_cast<const BYTE*>(shell_command.c_str());
    RegSetValueExW(key, nullptr, 0, REG_SZ, data,
                   static_cast<DWORD>((shell_command.size() + 1) *
                                      sizeof(wchar_t)));
    RegCloseKey(key);
  }
}

void RegisterFileAssociations() {
  wchar_t exe_path[MAX_PATH] = {0};
  if (GetModuleFileNameW(nullptr, exe_path, MAX_PATH) == 0) return;
  const std::wstring exe(exe_path);
  const std::wstring prog_id = L"Atlas.Book.1";

  RegisterFileType(L".epub", prog_id, L"Atlas Book");
  RegisterFileType(L".pdf", prog_id, L"Atlas Book");
  RegisterFileType(L".atlas", prog_id, L"Atlas Package");
  RegisterOpenCommand(prog_id, exe);

  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Single-instance: if an Atlas is already running, forward any opened
  // documents to it and exit without creating a second window.
  HANDLE single_instance =
      CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (single_instance != nullptr &&
      GetLastError() == ERROR_ALREADY_EXISTS) {
    std::vector<std::string> open_paths;
    for (const std::string& arg : GetCommandLineArguments()) {
      if (IsSupportedOpenPath(arg)) {
        open_paths.push_back(arg);
      }
    }
    ForwardOpenedFiles(open_paths);
    CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }

  // Ensure "Open with Atlas" is available for our document types. The handle
  // is intentionally kept open for the process lifetime so subsequent launches
  // keep detecting this instance.
  RegisterFileAssociations();
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Atlas", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
