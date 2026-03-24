import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var viewModel: StationsViewModel
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Favoris")
        }
    }

    @ViewBuilder
    private var content: some View {
        if favoriteStations.isEmpty {
            ContentUnavailableView(
                "Aucun favori",
                systemImage: "star",
                description: Text("Ajoute une station en favori depuis sa fiche.")
            )
        } else {
            List {
                ForEach(favoriteStations) { station in
                    NavigationLink {
                        StationDetailView(station: station)
                    } label: {
                        StationRowView(
                            station: station,
                            selectedFuel: viewModel.selectedFuel,
                            userLocation: locationManager.currentLocation,
                            priceColor: priceColor(for: station)
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var favoriteStations: [FuelStation] {
        viewModel.allStations
            .filter { favoritesStore.favoriteIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsPrice = lhs.price(for: viewModel.selectedFuel) ?? Double.greatestFiniteMagnitude
                let rhsPrice = rhs.price(for: viewModel.selectedFuel) ?? Double.greatestFiniteMagnitude

                if lhsPrice == rhsPrice {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }

                return lhsPrice < rhsPrice
            }
    }

    private func priceColor(for station: FuelStation) -> Color {
        let prices = favoriteStations.compactMap { $0.price(for: viewModel.selectedFuel) }

        guard
            let currentPrice = station.price(for: viewModel.selectedFuel),
            let minPrice = prices.min(),
            let maxPrice = prices.max()
        else {
            return .green
        }

        guard maxPrice > minPrice else {
            return .green
        }

        let ratio = (currentPrice - minPrice) / (maxPrice - minPrice)
        let hue = (1 - ratio) * 0.33
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }
}
