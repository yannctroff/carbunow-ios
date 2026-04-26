import SwiftUI
import CoreLocation

struct StationRowView: View {
    let station: FuelStation
    let selectedFuel: FuelType
    let userLocation: CLLocation?
    var priceColor: Color = .green

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                UrbanSectionHeader("Station", subtitle: station.subtitle.isEmpty ? nil : station.subtitle)

                Text(station.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(UrbanTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    UrbanMetricChip(text: "\(station.availableFuelTypes.count) carburants")

                    if let distance = station.distance(from: userLocation) {
                        UrbanMetricChip(text: formattedDistance(distance))
                    }
                }

                Text(station.updatedAtText ?? "Mise à jour inconnue")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            priceBlock
        }
        .urbanCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var priceBlock: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(selectedFuel.displayName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(selectedFuel.urbanAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(selectedFuel.urbanAccent.opacity(0.16))
                )

            if station.shouldShowRuptureBadge(for: selectedFuel) {
                Text("Rupture")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(UrbanTheme.danger)
                    .multilineTextAlignment(.trailing)
            } else if let price = station.price(for: selectedFuel) {
                Text(String(format: "%.3f €/L", price))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(priceColor)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
                    .multilineTextAlignment(.trailing)
            }

            Text("ID \(station.id)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(UrbanTheme.frost)
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
