//
//  PushNotificationManager.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 19/03/2026.
//


import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var apnsTokenHex: String = ""

    private let defaults = UserDefaults.standard
    private let tokenKey = "push.apnsTokenHex"

    private init() {
        apnsTokenHex = defaults.string(forKey: tokenKey) ?? ""
    }

    func requestAuthorizationAndRegister() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notification permission:", granted)

            guard granted else { return }

            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("❌ Notification authorization error:", error.localizedDescription)
        }
    }

    func updateAPNsToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        guard token != apnsTokenHex else { return }

        apnsTokenHex = token
        defaults.set(token, forKey: tokenKey)

        print("📱 APNs token:", token)

        await syncTokenToServerIfPossible()
    }

    func syncTokenToServerIfPossible() async {
        guard !apnsTokenHex.isEmpty else { return }

        do {
            try await AlertsAPI.shared.registerDeviceToken(apnsTokenHex)
        } catch {
            print("❌ Failed to sync APNs token to server:", error.localizedDescription)
        }
    }
}