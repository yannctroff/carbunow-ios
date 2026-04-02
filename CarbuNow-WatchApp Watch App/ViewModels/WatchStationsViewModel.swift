//
//  WatchStationsViewModel.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation
import CoreLocation
import Combine

enum WatchStationSortOption: String, CaseIterable, Identifiable {
    case distance
    case price

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance:
            return "Distance"
        case .price:
            return "Prix"
        }
    }
}

@MainActor
final class WatchStationsViewModel: ObservableObject {
    @Published var stations: [FuelStation] = []
    @Published var selectedFuel: FuelType = .gazole
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate: Date?
    @Published var sortOption: WatchStationSortOption = .distance

    private let apiService = WatchFuelAPIService.shared
    private let searchRadiusKm: Double = 15
    private var cancellables = Set<AnyCancellable>()
    private var lastLocation: CLLocation?

    init() {
        WatchConnectivityBridge.shared.activate()
        loadSelectedFuel()
        observeFuelSync()
    }

    func loadSelectedFuel() {
        if let saved = SharedDefaults.shared.string(forKey: SharedDefaults.defaultFuelKey),
           let fuel = FuelType(rawValue: saved) {
            selectedFuel = fuel
        } else if let saved = UserDefaults.standard.string(forKey: SharedDefaults.defaultFuelKey),
                  let fuel = FuelType(rawValue: saved) {
            selectedFuel = fuel
        } else {
            selectedFuel = .gazole
        }

        print("⌚️ selectedFuel chargé sur Watch: \(selectedFuel.rawValue)")
    }

    func refresh(using location: CLLocation?) async {
        guard let location else {
            errorMessage = "Position indisponible."
            stations = []
            isLoading = false
            return
        }

        lastLocation = location
        isLoading = true
        errorMessage = nil
        loadSelectedFuel()

        do {
            let fetched = try await apiService.fetchStations(
                around: location.coordinate,
                radiusKm: searchRadiusKm,
                limit: 100
            )

            let filtered = fetched.filter { $0.isAvailable(for: selectedFuel) }
            stations = sortStations(filtered, userLocation: location)
            lastRefreshDate = Date()

            print("⌚️ refresh Watch terminé avec carburant: \(selectedFuel.rawValue)")
        } catch {
            stations = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func applySort(using location: CLLocation?) {
        stations = sortStations(stations, userLocation: location)
    }

    private func sortStations(_ stations: [FuelStation], userLocation: CLLocation?) -> [FuelStation] {
        switch sortOption {
        case .distance:
            return stations.sorted {
                let lhsDistance = $0.distance(from: userLocation) ?? .greatestFiniteMagnitude
                let rhsDistance = $1.distance(from: userLocation) ?? .greatestFiniteMagnitude
                return lhsDistance < rhsDistance
            }

        case .price:
            return stations.sorted {
                let lhsPrice = $0.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                let rhsPrice = $1.price(for: selectedFuel) ?? .greatestFiniteMagnitude

                if lhsPrice == rhsPrice {
                    let lhsDistance = $0.distance(from: userLocation) ?? .greatestFiniteMagnitude
                    let rhsDistance = $1.distance(from: userLocation) ?? .greatestFiniteMagnitude
                    return lhsDistance < rhsDistance
                }

                return lhsPrice < rhsPrice
            }
        }
    }

    private func observeFuelSync() {
        NotificationCenter.default.publisher(for: .watchDefaultFuelDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }

                print("⌚️ Notification watchDefaultFuelDidChange reçue")

                self.loadSelectedFuel()

                if let location = self.lastLocation {
                    Task {
                        await self.refresh(using: location)
                    }
                } else {
                    self.applySort(using: nil)
                }
            }
            .store(in: &cancellables)
    }
}
