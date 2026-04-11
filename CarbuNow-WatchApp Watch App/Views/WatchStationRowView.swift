//
//  WatchStationRowView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import SwiftUI
import CoreLocation

struct WatchStationRowView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?

    private var priceText: String {
        if station.shouldShowRuptureBadge(for: selectedFuel) {
            return "Rupture"
        }

        if let price = station.price(for: selectedFuel) {
            return String(format: "%.3f €/L", price)
        }

        return "—"
    }

    private var priceColor: Color {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(station.displayName)
                .font(.headline)
                .lineLimit(2)

            Text(priceText)
                .font(.subheadline)
                .foregroundStyle(priceColor)

            if let distanceText {
                Text(distanceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
