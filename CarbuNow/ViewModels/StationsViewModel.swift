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
import SwiftUI

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

        WatchConnectivityBridge.shared.activate()

        if let saved = SharedDefaults.shared.string(forKey: SharedDefaults.defaultFuelKey),
           let fuel = FuelType(rawValue: saved) {
            self.selectedFuel = fuel
        } else if let saved = UserDefaults.standard.string(forKey: "defaultFuel"),
                  let fuel = FuelType(rawValue: saved) {
            self.selectedFuel = fuel
        } else {
            self.selectedFuel = .gazole
        }

        let savedRadius = UserDefaults.standard.double(forKey: "searchRadiusKm")
        self.searchRadiusKm = savedRadius == 0 ? 15 : min(max(savedRadius, 0), 100)

        WatchConnectivityBridge.shared.syncDefaultFuel(self.selectedFuel)
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
        SharedDefaults.shared.set(fuel.rawValue, forKey: SharedDefaults.defaultFuelKey)
        WatchConnectivityBridge.shared.syncDefaultFuel(fuel)
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
        return (min: minPrice, max: maxPrice)
    }
}

enum VehicleEstimationMode: String, Codable, CaseIterable, Identifiable {
    case quick
    case complete

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick:
            return "Rapide"
        case .complete:
            return "Complet"
        }
    }

    var descriptionText: String {
        switch self {
        case .quick:
            return "Saisie de la distance parcourue et de la consommation moyenne."
        case .complete:
            return "Ajoute aussi l’autonomie restante et la vitesse moyenne."
        }
    }
}

struct VehicleProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var fuelType: FuelType
    var tankCapacityLiters: Double
    var consumptionLitersPer100km: Double

    var dashboardModeRawValue: String
    var tripDistanceKm: Double?
    var tripAverageConsumptionLitersPer100km: Double?
    var remainingRangeKm: Double?
    var tripAverageSpeedKmh: Double?
    var resetTripAtFillUp: Bool

    var estimationMode: VehicleEstimationMode {
        get { VehicleEstimationMode(rawValue: dashboardModeRawValue) ?? .quick }
        set { dashboardModeRawValue = newValue.rawValue }
    }

    var effectiveAverageConsumptionLitersPer100km: Double {
        tripAverageConsumptionLitersPer100km ?? consumptionLitersPer100km
    }

    init(
        id: UUID = UUID(),
        label: String,
        fuelType: FuelType,
        tankCapacityLiters: Double,
        consumptionLitersPer100km: Double,
        dashboardMode: VehicleEstimationMode = .quick,
        tripDistanceKm: Double? = nil,
        tripAverageConsumptionLitersPer100km: Double? = nil,
        remainingRangeKm: Double? = nil,
        tripAverageSpeedKmh: Double? = nil,
        resetTripAtFillUp: Bool = false
    ) {
        self.id = id
        self.label = label
        self.fuelType = fuelType
        self.tankCapacityLiters = tankCapacityLiters
        self.consumptionLitersPer100km = consumptionLitersPer100km
        self.dashboardModeRawValue = dashboardMode.rawValue
        self.tripDistanceKm = tripDistanceKm
        self.tripAverageConsumptionLitersPer100km = tripAverageConsumptionLitersPer100km
        self.remainingRangeKm = remainingRangeKm
        self.tripAverageSpeedKmh = tripAverageSpeedKmh
        self.resetTripAtFillUp = resetTripAtFillUp
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case fuelType
        case tankCapacityLiters
        case consumptionLitersPer100km
        case dashboardModeRawValue
        case tripDistanceKm
        case tripAverageConsumptionLitersPer100km
        case remainingRangeKm
        case tripAverageSpeedKmh
        case resetTripAtFillUp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        fuelType = try container.decode(FuelType.self, forKey: .fuelType)
        tankCapacityLiters = try container.decode(Double.self, forKey: .tankCapacityLiters)
        consumptionLitersPer100km = try container.decode(Double.self, forKey: .consumptionLitersPer100km)

        dashboardModeRawValue = try container.decodeIfPresent(String.self, forKey: .dashboardModeRawValue) ?? VehicleEstimationMode.quick.rawValue
        tripDistanceKm = try container.decodeIfPresent(Double.self, forKey: .tripDistanceKm)
        tripAverageConsumptionLitersPer100km = try container.decodeIfPresent(Double.self, forKey: .tripAverageConsumptionLitersPer100km)
        remainingRangeKm = try container.decodeIfPresent(Double.self, forKey: .remainingRangeKm)
        tripAverageSpeedKmh = try container.decodeIfPresent(Double.self, forKey: .tripAverageSpeedKmh)
        resetTripAtFillUp = try container.decodeIfPresent(Bool.self, forKey: .resetTripAtFillUp) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(fuelType, forKey: .fuelType)
        try container.encode(tankCapacityLiters, forKey: .tankCapacityLiters)
        try container.encode(consumptionLitersPer100km, forKey: .consumptionLitersPer100km)
        try container.encode(dashboardModeRawValue, forKey: .dashboardModeRawValue)
        try container.encodeIfPresent(tripDistanceKm, forKey: .tripDistanceKm)
        try container.encodeIfPresent(tripAverageConsumptionLitersPer100km, forKey: .tripAverageConsumptionLitersPer100km)
        try container.encodeIfPresent(remainingRangeKm, forKey: .remainingRangeKm)
        try container.encodeIfPresent(tripAverageSpeedKmh, forKey: .tripAverageSpeedKmh)
        try container.encode(resetTripAtFillUp, forKey: .resetTripAtFillUp)
    }
}

@MainActor
final class VehicleSettingsStore: ObservableObject {
    static let shared = VehicleSettingsStore()

    @Published private(set) var vehicles: [VehicleProfile] = []
    @Published var selectedVehicleID: String = "" {
        didSet {
            UserDefaults.standard.set(selectedVehicleID, forKey: selectedVehicleIDKey)
        }
    }

    var selectedVehicle: VehicleProfile? {
        vehicles.first { $0.id.uuidString == selectedVehicleID }
    }

    private let vehiclesKey = "vehicleSettings.vehicles"
    private let selectedVehicleIDKey = "vehicleSettings.selectedVehicleID"

    private init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([VehicleProfile].self, from: data) {
            vehicles = decoded.sorted {
                $0.label.localizedStandardCompare($1.label) == .orderedAscending
            }
        } else {
            vehicles = []
        }

        let savedSelectedID = UserDefaults.standard.string(forKey: selectedVehicleIDKey) ?? ""

        if vehicles.contains(where: { $0.id.uuidString == savedSelectedID }) {
            selectedVehicleID = savedSelectedID
        } else {
            selectedVehicleID = vehicles.first?.id.uuidString ?? ""
        }
    }

    func addVehicle(
        label: String,
        fuelType: FuelType,
        tankCapacityLiters: Double,
        consumptionLitersPer100km: Double,
        dashboardMode: VehicleEstimationMode = .quick,
        tripDistanceKm: Double? = nil,
        tripAverageConsumptionLitersPer100km: Double? = nil,
        remainingRangeKm: Double? = nil,
        tripAverageSpeedKmh: Double? = nil,
        resetTripAtFillUp: Bool = false
    ) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        let newVehicle = VehicleProfile(
            label: trimmedLabel.isEmpty ? "Véhicule" : trimmedLabel,
            fuelType: fuelType,
            tankCapacityLiters: tankCapacityLiters,
            consumptionLitersPer100km: consumptionLitersPer100km,
            dashboardMode: dashboardMode,
            tripDistanceKm: tripDistanceKm,
            tripAverageConsumptionLitersPer100km: tripAverageConsumptionLitersPer100km,
            remainingRangeKm: remainingRangeKm,
            tripAverageSpeedKmh: tripAverageSpeedKmh,
            resetTripAtFillUp: resetTripAtFillUp
        )

        vehicles.append(newVehicle)
        persist()

        if selectedVehicleID.isEmpty {
            selectedVehicleID = newVehicle.id.uuidString
        }
    }

    func updateVehicle(_ vehicle: VehicleProfile) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index] = vehicle
        persist()
    }

    func deleteVehicles(at offsets: IndexSet) {
        let idsToDelete = offsets.map { vehicles[$0].id.uuidString }
        vehicles.remove(atOffsets: offsets)

        if idsToDelete.contains(selectedVehicleID) {
            selectedVehicleID = vehicles.first?.id.uuidString ?? ""
        }

        persist()
    }

    func deleteVehicle(_ vehicle: VehicleProfile) {
        guard let index = vehicles.firstIndex(of: vehicle) else { return }
        vehicles.remove(at: index)

        if selectedVehicleID == vehicle.id.uuidString {
            selectedVehicleID = vehicles.first?.id.uuidString ?? ""
        }

        persist()
    }

    func selectVehicle(_ vehicle: VehicleProfile) {
        selectedVehicleID = vehicle.id.uuidString
    }

    private func persist() {
        vehicles.sort {
            $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }

        if let encoded = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(encoded, forKey: vehiclesKey)
        }

        if !vehicles.contains(where: { $0.id.uuidString == selectedVehicleID }) {
            selectedVehicleID = vehicles.first?.id.uuidString ?? ""
        }
    }
}
