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

            ForEach(station.prices, id: \.self) { price in
                HStack {
                    Text(price.type.displayName)
                    Spacer()
                    Text(String(format: "%.3f €/L", price.price))
                        .bold()
                }

                if price != station.prices.last {
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

            ForEach(station.prices, id: \.self) { price in
                let isActive = alertManager.isAlertActive(
                    stationID: station.id,
                    fuelType: price.type.rawValue
                )

                Button {
                    Task {
                        await activateAlert(for: price.type)
                    }
                } label: {
                    HStack {
                        Image(systemName: isActive ? "bell.badge.fill" : "bell.badge")

                        Text(isActive
                             ? "Alerte \(price.type.displayName) active"
                             : "Activer alerte \(price.type.displayName)")

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
        let mapItem = MKMapItem(
            location: CLLocation(
                latitude: station.coordinate.latitude,
                longitude: station.coordinate.longitude
            ),
            address: nil
        )
        
        mapItem.name = station.displayName
        mapItem.openInMaps()
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
