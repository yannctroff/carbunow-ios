//
//  HomeView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var viewModel: StationsViewModel

    var body: some View {
        TabView {
            NavigationStack {
                content
                    .navigationTitle("CarbuNow")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                locationManager.requestPermission()
                                locationManager.startUpdating()
                            } label: {
                                Image(systemName: "location.fill")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Autour de moi", systemImage: "fuelpump.fill")
            }

            FavoritesView()
                .tabItem {
                    Label("Favoris", systemImage: "star.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape.fill")
                }
        }
        .task {
            await viewModel.loadStations()
        }
        .onAppear {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else {
                locationManager.startUpdating()
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            filtersSection

            if viewModel.isLoading {
                Spacer()
                ProgressView("Chargement des stations...")
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                    Text("Erreur")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredAndSortedStations(userLocation: locationManager.currentLocation)) { station in
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
    }

    private var filtersSection: some View {
        VStack(spacing: 10) {
            Picker("Carburant", selection: $viewModel.selectedFuel) {
                ForEach(FuelType.allCases) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tri", selection: $viewModel.sortOption) {
                ForEach(StationSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}