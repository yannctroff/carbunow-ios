//
//  CarbuNowApp.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//

import SwiftUI

@main
struct CarbuNowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
//                .environmentObject(priceAlertManager)
        }
    }
}
