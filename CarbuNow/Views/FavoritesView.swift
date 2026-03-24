//
//  FavoritesView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var viewModel: StationsViewModel
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            let favorites = viewModel.allStations.filter { favoritesStore.favoriteIDs.contains($0.id) }

            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "Aucun favori",
                        systemImage: "star",
                        description: Text("Ajoute une station en favori depuis sa fiche.")
                    )
                } else {
                    List {
                        ForEach(favorites) { station in
                            NavigationLink {
                                StationDetailView(station: station)
                            } label: {
                                StationRowView(
                                    station: station,
                                    selectedFuel: viewModel.selectedFuel,
                                    userLocation: locationManager.currentLocation
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favoris")
        }
    }
}