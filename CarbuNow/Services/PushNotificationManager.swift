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

struct StoredNotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let message: String
    let receivedAt: Date
}

@MainActor
final class NotificationInboxStore: ObservableObject {
    static let shared = NotificationInboxStore()

    @Published private(set) var items: [StoredNotificationItem] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "notificationInbox.items"
    private let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        load()
        pruneExpired()
    }

    func syncDeliveredNotifications() async {
        let center = UNUserNotificationCenter.current()
        let notifications = await center.deliveredNotifications()

        pruneExpired()

        for notification in notifications {
            upsert(notification: notification)
        }

        save()
    }

    func record(notification: UNNotification) {
        pruneExpired()
        upsert(notification: notification)
        save()
    }

    func pruneExpired(referenceDate: Date = Date()) {
        let cutoffDate = referenceDate.addingTimeInterval(-retentionInterval)
        let filtered = items.filter { $0.receivedAt >= cutoffDate }

        if filtered != items {
            items = filtered
            save()
        }
    }

    func clearAll() {
        items = []
        defaults.removeObject(forKey: storageKey)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func upsert(notification: UNNotification) {
        let content = notification.request.content
        let title = cleanedTitle(from: content)
        let message = cleanedMessage(from: content)
        let existingDate = items.first(where: { $0.id == notification.request.identifier })?.receivedAt ?? notification.date

        let item = StoredNotificationItem(
            id: notification.request.identifier,
            title: title,
            message: message,
            receivedAt: existingDate
        )

        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[existingIndex] = item
        } else {
            items.append(item)
        }

        items.sort { $0.receivedAt > $1.receivedAt }
    }

    private func cleanedTitle(from content: UNNotificationContent) -> String {
        let title = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Notification" : title
    }

    private func cleanedMessage(from content: UNNotificationContent) -> String {
        let subtitle = content.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = content.body.trimmingCharacters(in: .whitespacesAndNewlines)

        let combined = [subtitle, body]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return combined
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }

        do {
            items = try JSONDecoder().decode([StoredNotificationItem].self, from: data)
                .sorted { $0.receivedAt > $1.receivedAt }
        } catch {
            print("Impossible de relire la boite de notifications :", error.localizedDescription)
            items = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("Impossible de sauvegarder la boite de notifications :", error.localizedDescription)
        }
    }
}

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

private extension UNUserNotificationCenter {
    func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }
}
