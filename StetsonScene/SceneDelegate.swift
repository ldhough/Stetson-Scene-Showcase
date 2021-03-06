//
//  SceneDelegate.swift
//  StetsonScene
//
//  Created by Lannie Hough on 1/1/20.
//  Copyright © 2020 Lannie Hough. All rights reserved.
//

import UIKit
import SwiftUI

class AnyGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .began
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

extension SceneDelegate: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var config: Configuration!
    //var eventModelController:EventModelController!
    //var event:EventInstance!
    //var wheelNavigation:WheelNavigation!
    
    ///Establishes our Model Controller & Root View.  Starts the passing of our model controller around our views.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        //ViewModel Initiation
        let vm = EventViewModel()
        let se = EventSearchEngine()
        vm.retrieveFirebaseData(daysIntoYear: vm.getDaysIntoYear(nowPlusWeeks: 4), doFilter: true, searchEngine: se, filterOnlyTime: true)
        vm.buildingModelController.retrieveFirebaseDataBuildings()
        self.config = Configuration(vm)
        //vm.config = self.config
        
        //Keeps List views from having cell dividers
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().backgroundColor = UIColor.clear
        
        
        //SwiftUI root view
        let contentView = MainView(evm: vm)//.environment(\.managedObjectContext, context)
        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView.environmentObject(Configuration(vm)))
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    //===DEFAULT METHODS===//
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    
}

