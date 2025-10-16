//
//  Coffee_Grind_AnalyzerApp.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import UIKit

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - Main App

@main
struct Coffee_Grind_AnalyzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                //.preferredColorScheme(.dark) // Coffee app looks better in dark mode
        }
    }
}
