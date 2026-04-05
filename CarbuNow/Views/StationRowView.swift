import SwiftUI
import CoreLocation

struct StationRowView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?
    var priceColor: Color = .green

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.displayName)
                        .font(.headline)
                        .lineLimit(2)

                    Text(station.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text("ID \(station.id)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let updatedAtText = station.updatedAtText {
                        Text(updatedAtText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Mise à jour inconnue")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if station.shouldShowRuptureBadge(for: selectedFuel) {
                    Text("Rupture")
                        .font(.headline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.trailing)
                } else if let price = station.price(for: selectedFuel) {
                    Text(String(format: "%.3f €/L", price))
                        .font(.headline)
                        .foregroundStyle(priceColor)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("—")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack {
                Label("\(station.availableFuelTypes.count) carburants", systemImage: "fuelpump")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let distance = station.distance(from: userLocation) {
                    Text(formattedDistance(distance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            print("📋 [ROW] \(station.displayName) | \(station.updatedAtText ?? "maj=nil")")
        }
    }

    private func formattedDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}
