//
//  CarbuNow_WatchAppApp.swift
//  CarbuNow-WatchApp Watch App
//
//  Created by Yann CATTARIN on 31/03/2026.
//

import SwiftUI

@main
struct CarbuNowWatchApp: App {
    @StateObject private var viewModel = WatchStationsViewModel()
    @StateObject private var locationManager = WatchLocationManager()

    init() {
        WatchConnectivityBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(viewModel)
                .environmentObject(locationManager)
        }
    }
}
