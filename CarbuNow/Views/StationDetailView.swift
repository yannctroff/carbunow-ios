import SwiftUI
import MapKit
import CoreLocation

struct StationDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var alertManager = PriceAlertManager.shared
    @State private var alertMessage: AlertMessage?
    @State private var isSubmittingAlert = false
    @State private var showReportIssueSheet = false

    let station: FuelStation
    var showsCloseButton: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapSection
                infoSection
                pricesSection
                alertsSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle(station.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(isPresented: $showReportIssueSheet) {
            ReportIssueView(station: station)
        }
        .alert(item: $alertMessage) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var mapSection: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: station.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )) {
            Marker(station.displayName, coordinate: station.coordinate)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.displayName)
                .font(.title2.bold())

            Text(station.subtitle)
                .foregroundStyle(.secondary)

            Text("Station \(station.id)")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            if let updatedAtText = station.updatedAtText {
                Text(updatedAtText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Mise à jour le : inconnue")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prix disponibles")
                .font(.headline)

            ForEach(availableFuels, id: \.self) { fuel in
                HStack {
                    Text(fuel.displayName)
                    Spacer()

                    if station.hasActiveRupture(for: fuel) {
                        Text("Rupture")
                            .bold()
                            .foregroundStyle(.gray)
                    } else if let price = station.price(for: fuel) {
                        Text(String(format: "%.3f €/L", price))
                            .bold()
                    }
                }

                if fuel != availableFuels.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alertes de prix")
                .font(.headline)

            ForEach(availableFuels, id: \.self) { fuel in
                let isActive = alertManager.isAlertActive(
                    stationID: station.id,
                    fuelType: fuel.rawValue
                )

                Button {
                    Task {
                        await activateAlert(for: fuel)
                    }
                } label: {
                    HStack {
                        Image(systemName: isActive ? "bell.badge.fill" : "bell.badge")

                        Text(isActive
                             ? "Alerte \(fuel.displayName) active"
                             : "Activer alerte \(fuel.displayName)")

                        Spacer()

                        if isSubmittingAlert {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmittingAlert || isActive)
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

            Button {
                showReportIssueSheet = true
            } label: {
                Label("Signaler un problème", systemImage: "exclamationmark.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var availableFuels: [FuelType] {
        FuelType.allCases.filter { station.isAvailable(for: $0) }
    }

    private func activateAlert(for fuelType: FuelType) async {
        guard !isSubmittingAlert else { return }

        isSubmittingAlert = true
        defer { isSubmittingAlert = false }

        do {
            _ = try await alertManager.activateAlert(
                stationID: station.id,
                fuelType: fuelType.rawValue
            )

            alertMessage = AlertMessage(
                title: "Alerte activée",
                message: "L’alerte \(fuelType.displayName) est active."
            )
        } catch {
            alertMessage = AlertMessage(
                title: "Erreur",
                message: error.localizedDescription
            )
        }
    }

    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: station.coordinate.latitude,
            longitude: station.coordinate.longitude
        )

        let mapItem: MKMapItem

        if #available(iOS 26.0, *) {
            mapItem = MKMapItem(
                location: CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ),
                address: nil
            )
        } else {
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        }

        mapItem.name = station.displayName
        mapItem.openInMaps()
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

