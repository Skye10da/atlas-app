import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static let fileOpenChannelName = "com.atlasapp/file_open"

  /// The most recently opened document (cold-start "Open with Atlas").
  static var fileOpenedFile: URL?

  private var fileOpenChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for name in filenames {
      deliverOpenedFile(URL(fileURLWithPath: name))
    }
    super.application(sender, openFiles: filenames)
  }

  /// Called by [MainFlutterWindow] once the Flutter view is up. Installs the
  /// Dart-facing channel. Cold-start documents are pulled by Dart via
  /// `getInitialOpenedFile`; pushing here would race Dart's handler
  /// registration and can double-deliver the same cached copy.
  func installFileOpenChannel(_ channel: FlutterMethodChannel) {
    fileOpenChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getInitialOpenedFile":
        let path = AppDelegate.fileOpenedFile?.path
        AppDelegate.fileOpenedFile = nil
        result(path)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func deliverOpenedFile(_ url: URL) {
    guard url.isFileURL else { return }
    let copied = AppDelegate.copyToCache(url)
    AppDelegate.fileOpenedFile = copied
    if copied != nil {
      fileOpenChannel?.invokeMethod("onFileOpened", arguments: copied!.path)
    }
  }

  static func copyToCache(_ url: URL) -> URL? {
    let fm = FileManager.default
    guard let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
    let dest = dir.appendingPathComponent("opened_\(Int(Date().timeIntervalSince1970 * 1000)).\(url.pathExtension)")
    do {
      try? fm.removeItem(at: dest)
      try fm.copyItem(at: url, to: dest)
      return dest
    } catch {
      return nil
    }
  }
}