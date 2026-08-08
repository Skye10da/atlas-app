import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Cold start initiated by an "Open with Atlas" document. The Dart handler
    // is not live yet, so the path is stashed for getInitialOpenedFile.
    for context in connectionOptions.urlContexts {
      deliver(context.url, cold: true)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      deliver(context.url, cold: false)
    }
  }

  private func deliver(_ url: URL, cold: Bool) {
    guard url.isFileURL else { return }
    if let app = UIApplication.shared.delegate as? AppDelegate {
      if cold {
        app.storePendingOpenedFile(url)
      } else {
        app.deliverOpenedFile(url)
      }
    }
  }
}