//
//  StationSortOption.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import Foundation
import CoreLocation

enum StationSortOption: String, CaseIterable, Identifiable {
    case price = "Prix"
    case distance = "Distance"

    var id: String { rawValue }
}

@MainActor
final class StationsViewModel: ObservableObject {
    @Published var allStations: [FuelStation] = []
    @Published var selectedFuel: FuelType = .gazole
    @Published var sortOption: StationSortOption = .price
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = FuelAPIService()

    func loadStations() async {
        isLoading = true
        errorMessage = nil

        do {
            allStations = try await apiService.fetchStations()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func filteredAndSortedStations(userLocation: CLLocation?) -> [FuelStation] {
        let filtered = allStations.filter { $0.price(for: selectedFuel) != nil }

        switch sortOption {
        case .price:
            return filtered.sorted {
                ($0.price(for: selectedFuel) ?? .greatestFiniteMagnitude) <
                ($1.price(for: selectedFuel) ?? .greatestFiniteMagnitude)
            }

        case .distance:
            return filtered.sorted {
                ($0.distance(from: userLocation) ?? .greatestFiniteMagnitude) <
                ($1.distance(from: userLocation) ?? .greatestFiniteMagnitude)
            }
        }
    }
}