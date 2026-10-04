import SwiftUI
import UIKit

final class DexSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = DexHostingController(rootView: ContentView())
    self.window = window
    window.makeKeyAndVisible()
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(self, selector: #selector(updateUpsideDownOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    updateUpsideDownOrientation()
  }

  @objc private func updateUpsideDownOrientation() {
    guard UIDevice.current.orientation == .portraitUpsideDown,
          let windowScene = window?.windowScene else { return }
    window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portraitUpsideDown))
  }
}

private final class DexHostingController: UIHostingController<ContentView> {
  // iPhone's default controller mask excludes upside-down portrait. The Duo's
  // closed display must support it so the cover never gets stuck in landscape.
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
}
