//
//  WatchStationDetailView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import SwiftUI
import CoreLocation

struct WatchStationDetailView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?

    @State private var resolvedFuelTypes: [FuelType] = []
    @State private var hasLoadedResolvedFuelTypes = false
    @State private var isLoadingResolvedFuelTypes = false

    private var stationName: String {
        if let name = station.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        if let brand = station.brand?.trimmingCharacters(in: .whitespacesAndNewlines), !brand.isEmpty {
            return brand
        }

        return "Station \(station.id)"
    }

    private var displayedFuels: [FuelType] {
        if !resolvedFuelTypes.isEmpty {
            return resolvedFuelTypes
        }

        return initiallyKnownFuels
    }

    private var priceText: String {
        if shouldShowRupture(for: selectedFuel) {
            return "Rupture"
        }

        if let price = station.price(for: selectedFuel) {
            return String(format: "%.3f €/L", price)
        }

        return "—"
    }

    private var selectedFuelPriceColor: Color {
        if shouldShowRupture(for: selectedFuel) {
            return .red
        }

        if station.price(for: selectedFuel) != nil {
            return .green
        }

        return .secondary
    }

    private var distanceText: String? {
        guard let distance = station.distance(from: userLocation) else { return nil }

        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(stationName)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedFuel.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(priceText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedFuelPriceColor)
                }

                if let distanceText {
                    LabeledContent("Distance", value: distanceText)
                        .font(.caption)
                }

                if let updatedText = station.updatedAtText {
                    Text(updatedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !displayedFuels.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carburants")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ForEach(displayedFuels, id: \.self) { fuel in
                            HStack {
                                Text(fuel.displayName)
                                Spacer()

                                if shouldShowRupture(for: fuel) {
                                    Text("Rupture")
                                        .foregroundStyle(.red)
                                } else if let price = station.price(for: fuel) {
                                    Text(String(format: "%.3f €/L", price))
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .navigationTitle("Station")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: station.id) {
            hasLoadedResolvedFuelTypes = false
            resolvedFuelTypes = []
            await loadResolvedFuelTypesIfNeeded()
        }
    }

    private var initiallyKnownFuels: [FuelType] {
        FuelType.allCases.filter { station.price(for: $0) != nil }
    }

    private func shouldShowRupture(for fuel: FuelType) -> Bool {
        station.hasActiveRupture(for: fuel) && displayedFuels.contains(fuel)
    }

    private func loadResolvedFuelTypesIfNeeded() async {
        guard !hasLoadedResolvedFuelTypes, !isLoadingResolvedFuelTypes else { return }

        isLoadingResolvedFuelTypes = true
        defer { isLoadingResolvedFuelTypes = false }

        let fuelsKnownAtOpen = Set(initiallyKnownFuels)
        let stationID = station.id

        do {
            let fuelsWithHistory = try await withThrowingTaskGroup(of: FuelType?.self) { group in
                for fuel in FuelType.allCases {
                    group.addTask {
                        let history = try await WatchFuelAPIService.shared.fetchHistory(
                            stationID: stationID,
                            fuelType: fuel.rawValue,
                            days: 365
                        )

                        return history.contains { $0.price != nil } ? fuel : nil
                    }
                }

                var result = Set<FuelType>()

                for try await fuel in group {
                    if let fuel {
                        result.insert(fuel)
                    }
                }

                return result
            }

            let merged = fuelsKnownAtOpen.union(fuelsWithHistory)
            resolvedFuelTypes = FuelType.allCases.filter { merged.contains($0) }
            hasLoadedResolvedFuelTypes = true
        } catch {
            print("Erreur chargement carburants résolus Watch:", error)
            resolvedFuelTypes = initiallyKnownFuels
            hasLoadedResolvedFuelTypes = true
        }
    }
}
