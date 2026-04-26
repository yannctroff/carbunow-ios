import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: StationsViewModel
    @ObservedObject private var vehicleStore = VehicleSettingsStore.shared
    @ObservedObject private var priceAlertManager = PriceAlertManager.shared

    let hidesNavigationChrome: Bool

    @AppStorage("priceAlert.isEnabled") private var priceAlertIsEnabled = false
    @AppStorage("priceAlert.selectedStationID") private var selectedStationID = ""
    @AppStorage("priceAlert.selectedFuel") private var selectedFuelRawValue = FuelType.gazole.rawValue

    @State private var showVehicleEditor = false
    @State private var editingVehicle: VehicleProfile?
    @State private var showActiveAlertsView = false
    @State private var showAddAlertView = false
    @State private var showSavedPlacesView = false
    @State private var showPersonalHistoryView = false

    init(hidesNavigationChrome: Bool = false) {
        self.hidesNavigationChrome = hidesNavigationChrome
    }

    var body: some View {
        NavigationStack {
            List {
                if hidesNavigationChrome {
                    Text("Réglages")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .padding(.top, 16)
                }

                Section("Prix affiché par défaut") {
                    Picker("Carburant par défaut", selection: Binding(
                        get: { viewModel.selectedFuel },
                        set: { viewModel.setDefaultFuel($0) }
                    )) {
                        ForEach(FuelType.allCases) { fuel in
                            Text(fuel.displayName).tag(fuel)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Ce carburant sera utilisé par défaut sur la carte et dans la liste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                vehicleSection

                Section("Notification prix station") {
                    Toggle("Activer l’alerte de prix", isOn: $priceAlertIsEnabled)
                        .onChange(of: priceAlertIsEnabled) { _, newValue in
                            Task {
                                await updateGlobalAlertsState(isEnabled: newValue)
                            }
                        }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: priceAlertIsEnabled ? "bell.badge.fill" : "bell.slash")
                                .font(.title3)
                                .foregroundColor(priceAlertIsEnabled ? .accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(priceAlertIsEnabled ? "Notifications de prix activées" : "Notifications de prix désactivées")
                                    .font(.subheadline.weight(.semibold))

                                Text(
                                    priceAlertManager.activeAlerts.isEmpty
                                    ? "Aucune alerte enregistrée."
                                    : "\(priceAlertManager.activeAlerts.count) alerte\(priceAlertManager.activeAlerts.count > 1 ? "s" : "") active\(priceAlertManager.activeAlerts.count > 1 ? "s" : "")."
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        if !priceAlertManager.activeAlerts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(priceAlertManager.activeAlerts.prefix(3))) { alert in
                                    if let station = viewModel.availableStationsForAlerts.first(where: { $0.id == alert.stationID }),
                                       let fuel = FuelType(rawValue: alert.fuelType.lowercased()) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(.tint)
                                                .frame(width: 6, height: 6)

                                            Text("\(fuel.displayName) • \(station.displayName)")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    } else if let fuel = FuelType(rawValue: alert.fuelType.lowercased()) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(.tint)
                                                .frame(width: 6, height: 6)

                                            Text("\(fuel.displayName) • Station \(alert.stationID)")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                if priceAlertManager.activeAlerts.count > 3 {
                                    Text("+ \(priceAlertManager.activeAlerts.count - 3) autre\(priceAlertManager.activeAlerts.count - 3 > 1 ? "s" : "")")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        showActiveAlertsView = true
                    } label: {
                        Label("Voir les alertes actives", systemImage: "list.bullet.rectangle")
                    }
                    .disabled(priceAlertManager.activeAlerts.isEmpty)

                    Button {
                        showAddAlertView = true
                    } label: {
                        Label("Ajouter une nouvelle alerte", systemImage: "plus.circle.fill")
                    }

                    Label("Une notification sera envoyée quand le prix d’un carburant change dans la station choisie.", systemImage: "bell.badge")
                        .font(.footnote)

                    Label("Tu peux créer plusieurs alertes pour plusieurs stations et carburants.", systemImage: "info.circle")
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

                Section("Personnalisation") {
                    Button {
                        showSavedPlacesView = true
                    } label: {
                        Label("Prix autour de mes lieux", systemImage: "mappin.and.ellipse")
                    }

                    Button {
                        showPersonalHistoryView = true
                    } label: {
                        Label("Historique des consultations des stations", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("Widgets") {
                    Label("Ajoutez des widgets en cliquant sur + sur l'écran d'accueil de votre iPhone pour voir encore plus rapidement le prix de la station la + proche, la station au meillleur prix autour de votre position et les alertes actives des stations.",
                        systemImage: "square.grid.2x2")
                        .font(.footnote)
                }

                Section("Données") {
                    if let lastRefreshDate = viewModel.lastRefreshDate {
                        HStack {
                            Label("Dernière actualisation", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text(formattedDate(lastRefreshDate))
                                .foregroundStyle(.secondary)
                        }

                        Label("Les prix sont actualisés jusqu'à un délai de 15 minutes maximun", systemImage: "info.circle")
                    } else {
                        Label("Aucune actualisation encore effectuée", systemImage: "clock")
                    }
                }

                Section("Infos sur l'application") {
                    Label("Les données proviennent de l’API CarbuNow (via les données publiques de prix-carburants.gouv.fr)", systemImage: "network")
                }
            }
            .navigationTitle("Réglages")
            .toolbar(hidesNavigationChrome ? .hidden : .visible, for: .navigationBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollContentBackground(.hidden)
            .background(UrbanTheme.background.ignoresSafeArea())
            .tint(UrbanTheme.accent)
            .task(id: viewModel.availableStationsForAlerts.map(\.id).joined(separator: "|")) {
                priceAlertManager.refreshStationNames(using: viewModel.availableStationsForAlerts)
            }
            .sheet(isPresented: $showVehicleEditor) {
                VehicleEditorSheet(vehicle: editingVehicle)
            }
            .sheet(isPresented: $showActiveAlertsView) {
                NavigationStack {
                    ActiveAlertsListView(showsCloseButton: true)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showAddAlertView) {
                NavigationStack {
                    AddPriceAlertView()
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showSavedPlacesView) {
                NavigationStack {
                    SavedPlacesView(showsCloseButton: true)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showPersonalHistoryView) {
                NavigationStack {
                    PersonalHistoryView(showsCloseButton: true)
                        .environmentObject(viewModel)
                }
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
                .pickerStyle(.menu)

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
                    fuelType: fuel.rawValue.lowercased(),
                    stationName: viewModel.availableStationsForAlerts.first(where: { $0.id == selectedStationID })?.displayName
                )
            } catch {
                print("❌ Activation alerte impossible :", error.localizedDescription)
            }
        }
    }

    private func updateGlobalAlertsState(isEnabled: Bool) async {
        if !isEnabled {
            await priceAlertManager.setAllAlertsEnabled(false)
            return
        }

        await priceAlertManager.setAllAlertsEnabled(true)
        syncAlertIfPossible()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

struct ActiveAlertsListView: View {
    @EnvironmentObject private var viewModel: StationsViewModel
    @ObservedObject private var alertManager = PriceAlertManager.shared
    @Environment(\.dismiss) private var dismiss

    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        List {
            if alertManager.activeAlerts.isEmpty {
                ContentUnavailableView(
                    "Aucune alerte active",
                    systemImage: "bell.slash",
                    description: Text("Ajoute une alerte pour surveiller le prix d’un carburant dans une station.")
                )
            } else {
                ForEach(alertManager.activeAlerts) { alert in
                    VStack(alignment: .leading, spacing: 6) {
                        if let station = viewModel.availableStationsForAlerts.first(where: { $0.id == alert.stationID }) {
                            Text(station.displayName)
                                .font(.body.weight(.semibold))
                        } else {
                            Text("Station \(alert.stationID)")
                                .font(.body.weight(.semibold))
                        }

                        if let fuel = FuelType(rawValue: alert.fuelType.lowercased()) {
                            Text(fuel.displayName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Supprimer", role: .destructive) {
                            Task {
                                try? await alertManager.removeAlert(
                                    stationID: alert.stationID,
                                    fuelType: alert.fuelType
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Alertes actives")
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

private struct AddPriceAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: StationsViewModel
    @ObservedObject private var alertManager = PriceAlertManager.shared

    @State private var selectedStationID = ""
    @State private var selectedFuelRawValue = FuelType.gazole.rawValue
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var selectedFuel: FuelType? {
        FuelType(rawValue: selectedFuelRawValue)
    }

    var body: some View {
        Form {
            Section("Nouvelle alerte") {
                Picker("Station surveillée", selection: $selectedStationID) {
                    Text("Choisir").tag("")
                    ForEach(viewModel.availableStationsForAlerts) { station in
                        Text(station.displayName).tag(station.id)
                    }
                }
                .pickerStyle(.navigationLink)

                Picker("Carburant surveillé", selection: $selectedFuelRawValue) {
                    ForEach(FuelType.allCases) { fuel in
                        Text(fuel.displayName).tag(fuel.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            if let station = viewModel.availableStationsForAlerts.first(where: { $0.id == selectedStationID }),
               let fuel = selectedFuel {
                Section("Aperçu") {
                    Text(station.displayName)

                    if let price = station.price(for: fuel) {
                        Text("Prix actuel \(fuel.displayName) : \(formattedPrice(price))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ce carburant n’est pas disponible actuellement dans cette station.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await createAlert()
                    }
                } label: {
                    HStack {
                        Label("Ajouter l’alerte", systemImage: "plus.circle.fill")
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isSubmitting || selectedStationID.isEmpty || selectedFuel == nil)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Nouvelle alerte")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }

    private func createAlert() async {
        guard let fuel = selectedFuel else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await alertManager.activateAlert(
                stationID: selectedStationID,
                fuelType: fuel.rawValue,
                stationName: viewModel.availableStationsForAlerts.first(where: { $0.id == selectedStationID })?.displayName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
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
