//
//  StationDetailView.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import SwiftUI
import MapKit

struct StationDetailView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let station: FuelStation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapSection
                infoSection
                pricesSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                favoritesStore.toggle(station)
            } label: {
                Image(systemName: favoritesStore.isFavorite(station) ? "star.fill" : "star")
            }
        }
    }

    private var mapSection: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: station.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )) {
            Marker(station.name, coordinate: station.coordinate)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.name)
                .font(.title2.bold())

            if let brand = station.brand, !brand.isEmpty {
                Text(brand)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(station.address)
            Text(station.city)

            if let updatedAt = station.updatedAt {
                Text("Mise à jour : \(formattedDate(updatedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prix")
                .font(.headline)

            ForEach(station.prices, id: \.self) { price in
                HStack {
                    Text(price.type.displayName)
                    Spacer()
                    Text(String(format: "%.3f €/L", price.price))
                        .bold()
                }
                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                openInMaps()
            } label: {
                Label("Ouvrir dans Plans", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: station.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = station.name
        mapItem.openInMaps()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}