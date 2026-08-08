import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static let fileOpenChannelName = "com.atlasapp/file_open"

  /// Document opened at cold start, kept so Dart can pull it even before the
  /// channel is live.
  private(set) static var fileOpenedFile: URL?

  private var fileOpenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: Self.fileOpenChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getInitialOpenedFile":
        result(self?.takePendingOpenedFile())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    fileOpenChannel = channel
    // Cold-start documents are pulled by Dart via `getInitialOpenedFile`, so no
    // push happens here. Pushing would race Dart's handler registration and can
    // double-deliver the same cached copy.
  }

  private func takePendingOpenedFile() -> String? {
    let path = Self.fileOpenedFile?.path
    Self.fileOpenedFile = nil
    return path
  }

  /// Stores a cold-start "Open with Atlas" document so Dart can pull it once
  /// the engine is up. The Dart handler is not registered yet, so a push would
  /// be lost.
  func storePendingOpenedFile(_ url: URL) {
    Self.fileOpenedFile = Self.copyToCache(url)
  }

  /// Forwards a document opened while the app is already running straight to
  /// Dart.
  func deliverOpenedFile(_ url: URL) {
    guard let copied = Self.copyToCache(url) else { return }
    fileOpenChannel?.invokeMethod("onFileOpened", arguments: copied.path)
  }

  /// Copies a file URL into the app caches so the reader can open a plain path.
  static func copyToCache(_ url: URL) -> URL? {
    guard url.isFileURL else { return nil }
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