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
    @StateObject private var versionChecker = VersionChecker()
    private let priceAlertManager = PriceAlertManager.shared

    init() {
        LaunchDebug.log(context: "SwiftUI App init")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(locationManager)
                .environmentObject(favoritesStore)

                // 🔥 CHECK VERSION AU LANCEMENT
                .task {
                    await versionChecker.check()
                }

                // 🔔 POPUP UPDATE
                .alert("Mise à jour disponible", isPresented: $versionChecker.showUpdateAlert) {
                    Button("Mettre à jour") {
                        if let url = URL(string: "https://apps.apple.com/fr/app/id6760706117") {
                            UIApplication.shared.open(url)
                        }
                    }

                    Button("Plus tard", role: .cancel) { }

                } message: {
                    Text("Une nouvelle version (\(versionChecker.latestVersion ?? "")) est disponible sur l’App Store.")
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)

                Task {
                    await NotificationInboxStore.shared.syncDeliveredNotifications()
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
