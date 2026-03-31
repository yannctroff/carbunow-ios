import SwiftUI
import CoreLocation

struct WatchRootView: View {
    @EnvironmentObject private var viewModel: WatchStationsViewModel
    @EnvironmentObject private var locationManager: WatchLocationManager

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
                            Task {
                                locationManager.requestLocation()
                                try? await Task.sleep(nanoseconds: 700_000_000)
                                await viewModel.refresh(using: locationManager.currentLocation)
                            }
                        }
                    }
                    .padding()
                } else if viewModel.stations.isEmpty {
                    VStack(spacing: 8) {
                        Text("Aucune station trouvée")
                            .font(.caption)
                            .multilineTextAlignment(.center)

                        Button("Actualiser") {
                            Task {
                                locationManager.requestLocation()
                                try? await Task.sleep(nanoseconds: 700_000_000)
                                await viewModel.refresh(using: locationManager.currentLocation)
                            }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            locationManager.requestLocation()
                            try? await Task.sleep(nanoseconds: 700_000_000)
                            await viewModel.refresh(using: locationManager.currentLocation)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            locationManager.requestPermissionIfNeeded()
            try? await Task.sleep(nanoseconds: 900_000_000)
            await viewModel.refresh(using: locationManager.currentLocation)
        }
    }
}