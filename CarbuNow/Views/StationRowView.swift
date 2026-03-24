import SwiftUI
import CoreLocation

struct StationRowView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(station.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let price = station.price(for: selectedFuel) {
                    Text(String(format: "%.3f €/L", price))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }

            Text([station.address, station.city].joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if let brand = station.brand, !brand.isEmpty {
                    Label(brand, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let distance = station.distance(from: userLocation) {
                    Text(formattedDistance(distance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}