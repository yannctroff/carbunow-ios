import SwiftUI
import UIKit
import UserNotifications

@main
struct CarbuNowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = StationsViewModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var favoritesStore = FavoritesStore()
    private let priceAlertManager = PriceAlertManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(locationManager)
                .environmentObject(favoritesStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)

                Task {
                    await resetBadgeOnServer()
                }
            }
        }
    }

    private func resetBadgeOnServer() async {
        let token = PushNotificationManager.shared.apnsTokenHex
        guard !token.isEmpty else { return }

        guard let url = URL(string: "https://api.carbunow.yannctr.fr/alerts/reset-badge") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "deviceToken": token
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("reset badge server error:", error)
        }
    }
}

