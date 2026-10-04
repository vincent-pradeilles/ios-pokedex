import UIKit

@main
final class AppDefinition: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    .all
  }

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "Pocket Dex", sessionRole: connectingSceneSession.role)
    configuration.delegateClass = DexSceneDelegate.self
    return configuration
  }
}
