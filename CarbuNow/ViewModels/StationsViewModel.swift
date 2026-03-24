//
//  StationsViewModel.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 24/03/2026.
//


import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
final class StationsViewModel: ObservableObject {
    @Published var allStations: [FuelStation] = []
    @Published var listStations: [FuelStation] = []
    @Published var selectedFuel: FuelType
    @Published var sortOption: StationSortOption = .price
    @Published var isLoading = false
    @Published var isListLoading = false
    @Published var errorMessage: String?
    @Published var listErrorMessage: String?
    @Published var searchRadiusKm: Double
    @Published var lastRefreshDate: Date?
    @Published var lastListRefreshDate: Date?

    private let apiService: FuelAPIService

    init() {
        self.apiService = FuelAPIService()

        if let saved = UserDefaults.standard.string(forKey: "defaultFuel"),
           let fuel = FuelType(rawValue: saved) {
            self.selectedFuel = fuel
        } else {
            self.selectedFuel = .gazole
        }

        let savedRadius = UserDefaults.standard.double(forKey: "searchRadiusKm")
        self.searchRadiusKm = savedRadius == 0 ? 15 : min(max(savedRadius, 0), 100)
    }

    var availableStationsForAlerts: [FuelStation] {
        let merged = allStations + listStations
        var seen = Set<String>()

        return merged
            .filter { station in
                guard !seen.contains(station.id) else { return false }
                seen.insert(station.id)
                return true
            }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }

    func loadStations(in region: MKCoordinateRegion, force: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchStations(
                in: region,
                limit: 200
            )
            allStations = fetched
            lastRefreshDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadListStations(userLocation: CLLocation?, force: Bool = false) async {
        guard let userLocation else {
            listStations = []
            listErrorMessage = "Localisation indisponible."
            return
        }

        isListLoading = true
        listErrorMessage = nil

        do {
            let fetched = try await apiService.fetchStations(
                around: userLocation.coordinate,
                radiusKm: searchRadiusKm <= 0 ? 100 : searchRadiusKm,
                limit: 300
            )
            listStations = fetched
            lastListRefreshDate = Date()
        } catch {
            listErrorMessage = error.localizedDescription
        }

        isListLoading = false
    }

    func filteredAndSortedStations(userLocation: CLLocation?, radiusKm: Double? = nil) -> [FuelStation] {
        let effectiveRadius = radiusKm ?? searchRadiusKm

        let filtered = allStations.filter { station in
            guard station.price(for: selectedFuel) != nil else { return false }

            if effectiveRadius <= 0 {
                return true
            }

            guard let distance = station.distance(from: userLocation) else { return true }
            return distance <= effectiveRadius * 1000
        }

        switch sortOption {
        case .price:
            return filtered.sorted {
                let lhs = $0.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                let rhs = $1.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                return lhs < rhs
            }

        case .distance:
            return filtered.sorted {
                let lhs = $0.distance(from: userLocation) ?? .greatestFiniteMagnitude
                let rhs = $1.distance(from: userLocation) ?? .greatestFiniteMagnitude
                return lhs < rhs
            }
        }
    }

    func filteredAndSortedListStations(userLocation: CLLocation?) -> [FuelStation] {
        let filtered = listStations.filter { station in
            guard station.price(for: selectedFuel) != nil else { return false }

            if searchRadiusKm <= 0 {
                return true
            }

            guard let distance = station.distance(from: userLocation) else { return true }
            return distance <= searchRadiusKm * 1000
        }

        switch sortOption {
        case .price:
            return filtered.sorted {
                let lhs = $0.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                let rhs = $1.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                return lhs < rhs
            }

        case .distance:
            return filtered.sorted {
                let lhs = $0.distance(from: userLocation) ?? .greatestFiniteMagnitude
                let rhs = $1.distance(from: userLocation) ?? .greatestFiniteMagnitude
                return lhs < rhs
            }
        }
    }

    func setDefaultFuel(_ fuel: FuelType) {
        selectedFuel = fuel
        UserDefaults.standard.set(fuel.rawValue, forKey: "defaultFuel")
    }

    func setSearchRadius(_ value: Double) {
        let clamped = min(max(value, 0), 100)
        searchRadiusKm = clamped
        UserDefaults.standard.set(clamped, forKey: "searchRadiusKm")
    }

    func priceBounds(userLocation: CLLocation?, radiusKm: Double? = nil) -> (min: Double, max: Double)? {
        let prices = filteredAndSortedStations(userLocation: userLocation, radiusKm: radiusKm)
            .compactMap { $0.price(for: selectedFuel) }

        guard let minPrice = prices.min(), let maxPrice = prices.max() else { return nil }
        return (minPrice, maxPrice)
    }
}