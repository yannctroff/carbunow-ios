import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: StationsViewModel

    @AppStorage("priceAlert.isEnabled") private var priceAlertIsEnabled = false
    @AppStorage("priceAlert.selectedStationID") private var selectedStationID = ""
    @AppStorage("priceAlert.selectedFuel") private var selectedFuelRawValue = FuelType.gazole.rawValue

    private let priceAlertManager = PriceAlertManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Prix affiché par défaut") {
                    Picker("Carburant par défaut", selection: Binding(
                        get: { viewModel.selectedFuel },
                        set: { viewModel.setDefaultFuel($0) }
                    )) {
                        ForEach(FuelType.allCases) { fuel in
                            Text(fuel.displayName).tag(fuel)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text("Ce carburant sera utilisé par défaut sur la carte, dans la liste et au prochain lancement de l’app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notification prix station") {
                    Toggle("Activer l’alerte de prix", isOn: $priceAlertIsEnabled)
                        .onChange(of: priceAlertIsEnabled) { _, newValue in
                            if newValue {
                                syncAlertIfPossible()
                            }
                        }

                    Picker("Station surveillée", selection: $selectedStationID) {
                        Text("Aucune").tag("")

                        ForEach(viewModel.availableStationsForAlerts) { station in
                            Text(station.displayName).tag(station.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedStationID) { _, _ in
                        syncAlertIfPossible()
                    }

                    Picker("Carburant surveillé", selection: $selectedFuelRawValue) {
                        ForEach(FuelType.allCases) { fuel in
                            Text(fuel.displayName).tag(fuel.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedFuelRawValue) { _, _ in
                        syncAlertIfPossible()
                    }

                    if let monitoredStation = viewModel.availableStationsForAlerts.first(where: { $0.id == selectedStationID }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Station suivie : \(monitoredStation.displayName)")
                                .font(.footnote)

                            if let watchedFuel = watchedFuel,
                               let currentPrice = monitoredStation.price(for: watchedFuel) {
                                Text("Prix actuel \(watchedFuel.displayName) : \(formattedPrice(currentPrice))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Ce carburant n’est pas disponible actuellement dans cette station.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Choisis une station parmi celles déjà chargées dans la carte ou la liste.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Label("Une notification sera envoyée quand le prix de ce carburant change dans la station choisie.", systemImage: "bell.badge")
                        .font(.footnote)

                    Label("Limité à 1 alerte uniquement.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Zone de recherche") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Rayon de recherche")
                            Spacer()
                            Text("\(Int(viewModel.searchRadiusKm)) km")
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { viewModel.searchRadiusKm },
                                set: { viewModel.setSearchRadius($0) }
                            ),
                            in: 0...100,
                            step: 1
                        )

                        Text("0 km = aucune limite.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Label("Le rayon de recherche appliqué affecte uniquement l'onglet Liste", systemImage: "info.circle")
                }

                Section("Données") {
                    if let lastRefreshDate = viewModel.lastRefreshDate {
                        HStack {
                            Label("Dernière actualisation", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text(formattedDate(lastRefreshDate))
                                .foregroundStyle(.secondary)
                        }

                        Label("Les prix sont actualisés tous les 10 minutes. (8h00, 8h10, ...)", systemImage: "info.circle")
                    } else {
                        Label("Aucune actualisation encore effectuée", systemImage: "clock")
                    }
                }

                Section("Infos sur l'application") {
                    Label("Les données proviennent de l’API CarbuNow", systemImage: "network")
                }
            }
            .navigationTitle("Réglages")
        }
    }

    private var watchedFuel: FuelType? {
        FuelType(rawValue: selectedFuelRawValue)
    }

    private func syncAlertIfPossible() {
        guard priceAlertIsEnabled else { return }
        guard !selectedStationID.isEmpty else { return }
        guard let fuel = watchedFuel else { return }
        
        Task {
            do {
                _ = try await priceAlertManager.activateAlert(
                    stationID: selectedStationID,
                    fuelType: fuel.rawValue.lowercased()
                )
            } catch {
                print("❌ Activation alerte impossible :", error.localizedDescription)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)) + "€"
    }
}
