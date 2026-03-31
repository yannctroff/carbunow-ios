//
//  WatchStationsViewModel.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation
import CoreLocation

@MainActor
final class WatchStationsViewModel: ObservableObject {
    @Published var stations: [FuelStation] = []
    @Published var selectedFuel: FuelType = .gazole
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate: Date?

    private let apiService = WatchFuelAPIService.shared
    private let searchRadiusKm: Double = 15

    init() {
        loadSelectedFuel()
    }

    func loadSelectedFuel() {
        if let saved = SharedDefaults.shared.string(forKey: SharedDefaults.defaultFuelKey),
           let fuel = FuelType(rawValue: saved) {
            selectedFuel = fuel
        } else {
            selectedFuel = .gazole
        }
    }

    func refresh(using location: CLLocation?) async {
        guard let location else {
            errorMessage = "Position indisponible."
            stations = []
            return
        }

        isLoading = true
        errorMessage = nil
        loadSelectedFuel()

        do {
            let fetched = try await apiService.fetchStations(
                around: location.coordinate,
                radiusKm: searchRadiusKm,
                limit: 100
            )

            let filtered = fetched
                .filter { $0.isAvailable(for: selectedFuel) }
                .sorted { lhs, rhs in
                    let lhsDistance = lhs.distance(from: location) ?? .greatestFiniteMagnitude
                    let rhsDistance = rhs.distance(from: location) ?? .greatestFiniteMagnitude
                    return lhsDistance < rhsDistance
                }

            stations = filtered
            lastRefreshDate = Date()
        } catch {
            stations = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func formattedDistance(for station: FuelStation, from location: CLLocation?) -> String? {
        guard let distance = station.distance(from: location) else { return nil }

        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    func formattedPrice(for station: FuelStation) -> String? {
        guard let price = station.price(for: selectedFuel) else { return nil }
        return String(format: "%.3f €/L", price)
    }

    func statusText(for station: FuelStation) -> String {
        if station.hasActiveRupture(for: selectedFuel) {
            return "Rupture"
        }

        if let price = formattedPrice(for: station) {
            return price
        }

        return "Indisponible"
    }
}