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

    private var displayedFuels: [FuelType] {
        FuelType.allCases.filter { station.price(for: $0) != nil }
    }

    private var priceText: String {
        if station.shouldShowRuptureBadge(for: selectedFuel) {
            return "Rupture"
        }

        if let price = station.price(for: selectedFuel) {
            return String(format: "%.3f €/L", price)
        }

        return "—"
    }

    private var selectedFuelPriceColor: Color {
        if station.shouldShowRuptureBadge(for: selectedFuel) {
            return .gray
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
                Text(station.displayName)
                    .font(.headline)

                if !station.subtitle.isEmpty {
                    Text(station.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                                if let price = station.price(for: fuel) {
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
    }
}
