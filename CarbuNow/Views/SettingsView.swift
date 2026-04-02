import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: StationsViewModel
    @ObservedObject private var vehicleStore = VehicleSettingsStore.shared

    @AppStorage("priceAlert.isEnabled") private var priceAlertIsEnabled = false
    @AppStorage("priceAlert.selectedStationID") private var selectedStationID = ""
    @AppStorage("priceAlert.selectedFuel") private var selectedFuelRawValue = FuelType.gazole.rawValue

    @State private var showVehicleEditor = false
    @State private var editingVehicle: VehicleProfile?

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

                    Text("Ce carburant sera utilisé par défaut sur la carte et dans la liste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                vehicleSection

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
            .sheet(isPresented: $showVehicleEditor) {
                VehicleEditorSheet(vehicle: editingVehicle)
            }
        }
    }

    private var vehicleSection: some View {
        Section("Véhicules") {
            if vehicleStore.vehicles.isEmpty {
                ContentUnavailableView(
                    "Aucun véhicule",
                    systemImage: "car",
                    description: Text("Ajoute un véhicule avec son carburant, son réservoir et sa consommation de référence.")
                )
            } else {
                Picker("Véhicule utilisé", selection: Binding(
                    get: { vehicleStore.selectedVehicleID },
                    set: { vehicleStore.selectedVehicleID = $0 }
                )) {
                    Text("Aucun").tag("")
                    ForEach(vehicleStore.vehicles) { vehicle in
                        Text(vehicle.label).tag(vehicle.id.uuidString)
                    }
                }
                .pickerStyle(.navigationLink)

                ForEach(vehicleStore.vehicles) { vehicle in
                    Button {
                        vehicleStore.selectVehicle(vehicle)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.label)
                                    .foregroundStyle(.primary)

                                Text("\(vehicle.fuelType.displayName) • \(formattedLiters(vehicle.tankCapacityLiters)) • \(formattedConsumption(vehicle.consumptionLitersPer100km))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if vehicleStore.selectedVehicleID == vehicle.id.uuidString {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Modifier") {
                            editingVehicle = vehicle
                            showVehicleEditor = true
                        }
                        .tint(.blue)

                        Button("Supprimer", role: .destructive) {
                            vehicleStore.deleteVehicle(vehicle)
                        }
                    }
                }
                .onDelete(perform: vehicleStore.deleteVehicles)
            }

            Button {
                editingVehicle = nil
                showVehicleEditor = true
            } label: {
                Label("Ajouter un véhicule", systemImage: "plus.circle.fill")
            }

            if let selectedVehicle = vehicleStore.selectedVehicle {
                Text("Véhicule actif : \(selectedVehicle.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sélectionne un véhicule pour l’utiliser dans la fiche station.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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

    private func formattedLiters(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.maximumFractionDigits = 1
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)) L"
    }

    private func formattedConsumption(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.maximumFractionDigits = 1
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(text) L/100"
    }
}

private struct VehicleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var vehicleStore = VehicleSettingsStore.shared

    let vehicle: VehicleProfile?

    @State private var label: String
    @State private var fuelType: FuelType
    @State private var tankCapacityText: String
    @State private var consumptionText: String

    init(vehicle: VehicleProfile?) {
        self.vehicle = vehicle
        _label = State(initialValue: vehicle?.label ?? "")
        _fuelType = State(initialValue: vehicle?.fuelType ?? .gazole)
        _tankCapacityText = State(initialValue: vehicle.map { VehicleEditorSheet.decimalString(for: $0.tankCapacityLiters) } ?? "")
        _consumptionText = State(initialValue: vehicle.map { VehicleEditorSheet.decimalString(for: $0.consumptionLitersPer100km) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Véhicule") {
                    TextField("Nom ou plaque", text: $label)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker("Carburant utilisé", selection: $fuelType) {
                        ForEach(FuelType.allCases) { fuel in
                            Text(fuel.displayName).tag(fuel)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    TextField("Capacité du réservoir (L)", text: $tankCapacityText)
                        .keyboardType(.decimalPad)

                    TextField("Consommation de référence (L/100)", text: $consumptionText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(vehicle == nil ? "Ajouter un véhicule" : "Modifier le véhicule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var parsedTankCapacity: Double? {
        Self.parseDecimal(tankCapacityText)
    }

    private var parsedConsumption: Double? {
        Self.parseDecimal(consumptionText)
    }

    private var canSave: Bool {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLabel.isEmpty else { return false }
        guard let parsedTankCapacity, parsedTankCapacity > 0 else { return false }
        guard let parsedConsumption, parsedConsumption > 0 else { return false }
        return true
    }

    private func save() {
        guard let parsedTankCapacity, let parsedConsumption else { return }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        if let vehicle {
            let updatedVehicle = VehicleProfile(
                id: vehicle.id,
                label: trimmedLabel,
                fuelType: fuelType,
                tankCapacityLiters: parsedTankCapacity,
                consumptionLitersPer100km: parsedConsumption,
                dashboardMode: vehicle.estimationMode,
                tripDistanceKm: vehicle.tripDistanceKm,
                tripAverageConsumptionLitersPer100km: vehicle.tripAverageConsumptionLitersPer100km,
                remainingRangeKm: vehicle.remainingRangeKm,
                tripAverageSpeedKmh: vehicle.tripAverageSpeedKmh,
                resetTripAtFillUp: vehicle.resetTripAtFillUp
            )
            vehicleStore.updateVehicle(updatedVehicle)
        } else {
            vehicleStore.addVehicle(
                label: trimmedLabel,
                fuelType: fuelType,
                tankCapacityLiters: parsedTankCapacity,
                consumptionLitersPer100km: parsedConsumption
            )
        }

        dismiss()
    }

    private static func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized)
    }

    private static func decimalString(for value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
