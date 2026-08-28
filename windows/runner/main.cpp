#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

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
  // Ensure "Open with Atlas" is available for our document types. Documents
  // opened this way arrive as command-line arguments and are handed to Dart
  // via the Dart entrypoint arguments below, one window per launch.
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
