//
//  SceneDelegate.swift
//  VectorFields
//
//  Created by Sachin Agrawal on 8/29/26.
//

import UIKit

// Apps built against the iOS 26 SDK must adopt the scene life cycle, so the window
// lives here rather than on the app delegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // UIKit builds the window itself when the scene manifest names a storyboard,
        // so only step in when it has not already done so
        guard window == nil else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = storyboard.instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released by the system, which happens shortly after
        // it enters the background, or when its session is discarded
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks that were paused while the scene was inactive
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Sent when the scene is about to move from active to inactive state, such as
        // for a temporary interruption like an incoming phone call
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as part of the transition from the background to the active state
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Release shared resources and save enough state to restore the scene later
    }
}
