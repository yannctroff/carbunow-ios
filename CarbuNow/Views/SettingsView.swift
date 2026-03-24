//
//  SettingsView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Application") {
                    Label("Version de base de CarbuNow", systemImage: "app.badge")
                    Label("Mode clair/sombre automatique", systemImage: "circle.lefthalf.filled")
                }

                Section("À venir") {
                    Label("Carte complète", systemImage: "map")
                    Label("Alerte prix", systemImage: "bell")
                    Label("Historique des prix", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Widget iPhone", systemImage: "square.grid.2x2")
                }
            }
            .navigationTitle("Réglages")
        }
    }
}