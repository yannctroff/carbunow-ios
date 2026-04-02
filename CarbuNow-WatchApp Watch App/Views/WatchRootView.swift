//
//  WatchRootView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import SwiftUI
import CoreLocation

struct WatchRootView: View {
    @EnvironmentObject private var viewModel: WatchStationsViewModel
    @EnvironmentObject private var locationManager: WatchLocationManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSortDialog = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stations.isEmpty {
                    ProgressView("Chargement…")
                } else if let errorMessage = viewModel.errorMessage, viewModel.stations.isEmpty {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)

                        Button("Réessayer") {
                            refreshNow()
                        }
                    }
                    .padding()
                } else if viewModel.stations.isEmpty {
                    VStack(spacing: 8) {
                        Text("Aucune station trouvée")
                            .font(.caption)
                            .multilineTextAlignment(.center)

                        Button("Actualiser") {
                            refreshNow()
                        }
                    }
                    .padding()
                } else {
                    List(viewModel.stations) { station in
                        NavigationLink {
                            WatchStationDetailView(
                                station: station,
                                selectedFuel: viewModel.selectedFuel,
                                userLocation: locationManager.currentLocation
                            )
                        } label: {
                            WatchStationRowView(
                                station: station,
                                selectedFuel: viewModel.selectedFuel,
                                userLocation: locationManager.currentLocation
                            )
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle(viewModel.selectedFuel.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSortDialog = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .confirmationDialog(
            "Trier par",
            isPresented: $showSortDialog,
            titleVisibility: .visible
        ) {
            Button("Distance") {
                viewModel.sortOption = .distance
                viewModel.applySort(using: locationManager.currentLocation)
            }

            Button("Prix") {
                viewModel.sortOption = .price
                viewModel.applySort(using: locationManager.currentLocation)
            }

            Button("Annuler", role: .cancel) { }
        }
        .task {
            refreshNow(initialDelay: 900_000_000)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WatchConnectivityBridge.shared.activate()
                refreshNow(initialDelay: 200_000_000)
            }
        }
    }

    private func refreshNow(initialDelay: UInt64 = 700_000_000) {
        Task {
            locationManager.requestPermissionIfNeeded()
            locationManager.requestLocation()
            try? await Task.sleep(nanoseconds: initialDelay)
            await viewModel.refresh(using: locationManager.currentLocation)
        }
    }
}
