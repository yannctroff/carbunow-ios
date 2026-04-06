//
//  AppDelegate.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 19/03/2026.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🚀 didFinishLaunching")

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("❌ Notification permission error:", error.localizedDescription)
            } else {
                print("🔔 Notification permission:", granted)
            }

            DispatchQueue.main.async {
                print("📡 registerForRemoteNotifications()")
                application.registerForRemoteNotifications()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs token:", token)

        Task {
            await PriceAlertManager.shared.registerDevice(token: token)
            await PushNotificationManager.shared.updateAPNsToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed:", error.localizedDescription)
        print("❌ APNs registration full error:", error)
    }
}
