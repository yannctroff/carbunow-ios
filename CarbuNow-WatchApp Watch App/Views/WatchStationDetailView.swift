import SwiftUI
import CoreLocation

struct WatchStationDetailView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?

    private var priceText: String {
        if station.hasActiveRupture(for: selectedFuel) {
            return "Rupture"
        }

        if let price = station.price(for: selectedFuel) {
            return String(format: "%.3f €/L", price)
        }

        return "Indisponible"
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
                        .foregroundStyle(station.hasActiveRupture(for: selectedFuel) ? .red : .green)
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

                if !station.availableFuelTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carburants")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ForEach(station.availableFuelTypes) { fuel in
                            HStack {
                                Text(fuel.displayName)
                                Spacer()

                                if station.hasActiveRupture(for: fuel) {
                                    Text("Rupture")
                                        .foregroundStyle(.red)
                                } else if let price = station.price(for: fuel) {
                                    Text(String(format: "%.3f", price))
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