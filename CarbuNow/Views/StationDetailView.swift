import SwiftUI
import MapKit
import CoreLocation

struct StationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @ObservedObject private var vehicleStore = VehicleSettingsStore.shared

    @StateObject private var alertManager = PriceAlertManager.shared
    @State private var alertMessage: AlertMessage?
    @State private var isSubmittingAlert = false
    @State private var showReportIssueSheet = false
    @State private var selectedHistoryFuel: FuelType?

    @State private var showAutonomyEstimatorSheet = false
    @State private var latestEstimation: FillEstimation?

    @State private var resolvedFuelTypes: [FuelType] = []
    @State private var hasLoadedResolvedFuelTypes = false
    @State private var isLoadingResolvedFuelTypes = false

    let station: FuelStation
    var showsCloseButton: Bool = false
    var initiallyResolvedFuelTypes: Set<FuelType> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapSection
                infoSection
                pricesSection
                historySection
                estimatedCostSection
                alertsSection
                actionsSection
            }
            .padding()
        }
        .background(UrbanTheme.background.ignoresSafeArea())
        .navigationTitle(station.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showReportIssueSheet) {
            ReportIssueView(station: station)
        }
        .sheet(isPresented: $showAutonomyEstimatorSheet) {
            if let selectedVehicle = vehicleStore.selectedVehicle {
                AutonomyEstimatorSheet(
                    vehicle: selectedVehicle,
                    station: station,
                    onEstimate: { estimation in
                        latestEstimation = estimation
                    }
                )
            }
        }
        .alert(item: $alertMessage) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task(id: station.id) {
            StationHistoryStore.shared.recordView(for: station)
            hasLoadedResolvedFuelTypes = false
            resolvedFuelTypes = []
            await loadResolvedFuelTypesIfNeeded()

            if selectedHistoryFuel == nil || !historyFuels.contains(selectedHistoryFuel!) {
                selectedHistoryFuel = historyFuels.first
            }
        }
        .onChange(of: historyFuels) {
            if selectedHistoryFuel == nil || !historyFuels.contains(selectedHistoryFuel!) {
                selectedHistoryFuel = historyFuels.first
            }
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
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(UrbanTheme.line, lineWidth: 1)
        )
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            UrbanSectionHeader("Station", subtitle: station.subtitle.isEmpty ? nil : station.subtitle)

            Text(station.displayName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(UrbanTheme.textPrimary)

            Text("Station \(station.id)")
                .font(.footnote)
                .foregroundStyle(UrbanTheme.frost)

            if let updatedAtText = station.updatedAtText {
                Text(updatedAtText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
            } else {
                Text("Mise à jour le : inconnue")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .urbanCard()
    }

    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UrbanSectionHeader("Carburants", subtitle: "Disponibilité et prix actuels")

            if displayedFuels.isEmpty {
                Text("Aucun carburant actuellement identifié pour cette station.")
                    .foregroundStyle(UrbanTheme.frost)
            } else {
                ForEach(displayedFuels, id: \.self) { fuel in
                    HStack {
                        Text(fuel.displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(UrbanTheme.textPrimary)
                        Spacer()

                        if station.hasActiveRupture(for: fuel) {
                            Text("Rupture")
                                .bold()
                                .foregroundStyle(UrbanTheme.danger)
                        } else if let price = station.price(for: fuel) {
                            Text(String(format: "%.3f €/L", price))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(fuel.urbanAccent)
                        } else {
                            Text("—")
                                .foregroundStyle(UrbanTheme.frost)
                        }
                    }

                    if fuel != displayedFuels.last {
                        Divider().overlay(UrbanTheme.line)
                    }
                }
            }
        }
        .urbanCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !historyFuels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(historyFuels, id: \.self) { fuel in
                            Button {
                                selectedHistoryFuel = fuel
                            } label: {
                                Text(fuel.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedHistoryFuel == fuel ? fuel.urbanAccent.opacity(0.18) : UrbanTheme.panelSoft,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(UrbanTheme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            StationPriceHistoryView(
                stationID: station.id,
                fuelType: selectedHistoryFuel?.rawValue ?? historyFuels.first?.rawValue ?? "gazole",
                fuelDisplayName: selectedHistoryFuel?.displayName ?? historyFuels.first?.displayName ?? "Gazole"
            )
        }
    }

    private var estimatedCostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            UrbanSectionHeader("Estimation", subtitle: "Coût et autonomie")

            if vehicleStore.vehicles.isEmpty {
                Text("Ajoute un véhicule dans Réglages pour estimer le plein dans cette fiche station.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if vehicleStore.selectedVehicle == nil {
                Text("Sélectionne un véhicule actif dans Réglages pour estimer le plein.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let selectedVehicle = vehicleStore.selectedVehicle {
                let fuel = selectedVehicle.fuelType

                if station.hasActiveRupture(for: fuel), stationHasConfirmedFuel(fuel) {
                    Text("Le \(fuel.displayName) est en rupture dans cette station.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let price = station.price(for: fuel) {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(title: "Véhicule", value: selectedVehicle.label)
                        detailRow(title: "Carburant utilisé", value: fuel.displayName)
                        detailRow(title: "Réservoir", value: formattedLiters(selectedVehicle.tankCapacityLiters))
                        detailRow(title: "Consommation de référence", value: formattedConsumption(selectedVehicle.consumptionLitersPer100km))
                        detailRow(title: "Prix au litre", value: formattedPricePerLiter(price))
                        detailRow(title: "Coût réservoir plein", value: formattedCurrency(selectedVehicle.tankCapacityLiters * price))

                        if let travelCostText {
                            detailRow(title: "Coût du déplacement", value: travelCostText)
                        } else {
                            detailRow(title: "Coût du déplacement", value: "Position indisponible")
                        }

                        Button {
                            showAutonomyEstimatorSheet = true
                        } label: {
                            Label("Estimer le plein par rapport à mon autonomie", systemImage: "fuelpump.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(UrbanCTAButtonStyle(tint: selectedVehicle.fuelType.urbanAccent, foreground: .white))

                        if let estimation = latestEstimation {
                            Divider()

                            detailRow(title: "Distance parcourue", value: formattedDistance(estimation.distanceKm))
                            detailRow(title: "Conso moyenne", value: formattedConsumption(estimation.averageConsumptionLitersPer100km))
                            detailRow(title: "Autonomie restante", value: formattedDistance(estimation.remainingRangeKm))

                            if let averageSpeedKmh = estimation.averageSpeedKmh {
                                detailRow(title: "Vitesse moyenne", value: formattedSpeed(averageSpeedKmh))
                            }

                            detailRow(title: "Carburant estimé à ajouter", value: formattedLiters(estimation.estimatedLitersToAdd))
                            detailRow(title: "Coût estimé du plein", value: formattedCurrency(estimation.estimatedFillCost))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Compléter jusqu’à")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(UrbanTheme.frost)

                                ForEach(estimation.fillLevelOptions) { option in
                                    detailRow(
                                        title: option.title,
                                        value: option.litersToAdd > 0
                                        ? "\(formattedLiters(option.litersToAdd)) • \(formattedCurrency(option.cost))"
                                        : "déjà atteint"
                                    )
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Appuyez sur le bouton ci-dessus pour saisir l’autonomie restante, la distance parcourue et la consommation moyenne affichées sur l’ordinateur de bord.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Ces informations se trouvent sur le tableau de bord en appuyant sur le bouton « << » du commodo d’essuie-glace, si l’ordinateur de bord a bien été réinitialisé après chaque plein.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Le carburant \(fuel.displayName) n’a pas de prix communiqué actuellement dans cette station.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .urbanCard()
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UrbanSectionHeader("Alertes", subtitle: "Surveiller un carburant")

            ForEach(alertableFuels, id: \.self) { fuel in
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

                        Text(
                            isActive
                            ? "Alerte \(fuel.displayName) active"
                            : "Activer alerte \(fuel.displayName)"
                        )

                        Spacer()

                        if isSubmittingAlert {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(UrbanGhostButtonStyle(border: isActive ? fuel.urbanAccent.opacity(0.35) : UrbanTheme.line))
                .disabled(isSubmittingAlert || isActive)
            }

            if alertableFuels.isEmpty {
                Text("Aucun carburant disponible pour les alertes.")
                    .font(.footnote)
                    .foregroundStyle(UrbanTheme.frost)
            }
        }
        .urbanCard()
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                openInMaps()
            } label: {
                Label("Ouvrir dans Plans", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(UrbanCTAButtonStyle())

            Button {
                showReportIssueSheet = true
            } label: {
                Label("Signaler un problème", systemImage: "exclamationmark.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(UrbanGhostButtonStyle())
        }
    }

    private var displayedFuels: [FuelType] {
        if !resolvedFuelTypes.isEmpty {
            return resolvedFuelTypes
        }

        return initiallyKnownFuels
    }

    private var historyFuels: [FuelType] {
        displayedFuels
    }

    private var alertableFuels: [FuelType] {
        displayedFuels
    }

    private var distanceFromUserKm: Double? {
        guard let userLocation = locationManager.currentLocation else { return nil }

        let stationLocation = CLLocation(
            latitude: station.coordinate.latitude,
            longitude: station.coordinate.longitude
        )

        let distanceMeters = userLocation.distance(from: stationLocation)
        return distanceMeters / 1000
    }

    private var travelCostText: String? {
        guard let selectedVehicle = vehicleStore.selectedVehicle,
              let price = station.price(for: selectedVehicle.fuelType),
              let distanceKm = distanceFromUserKm else {
            return nil
        }

        let litersNeeded = (distanceKm / 100.0) * selectedVehicle.consumptionLitersPer100km
        let cost = litersNeeded * price

        return "\(formattedCurrency(cost)) (\(formattedDistance(distanceKm)) depuis vous)"
    }

    private func loadResolvedFuelTypesIfNeeded() async {
        guard !hasLoadedResolvedFuelTypes, !isLoadingResolvedFuelTypes else { return }

        await MainActor.run {
            isLoadingResolvedFuelTypes = true
        }

        let fuelsKnownAtOpen = Set(initiallyKnownFuels)

        do {
            let fuelsWithHistory = try await withThrowingTaskGroup(of: FuelType?.self) { group in
                for fuel in FuelType.allCases {
                    group.addTask {
                        let history = try await FuelAPIService.shared.fetchHistory(
                            stationID: station.id,
                            fuelType: fuel.rawValue,
                            days: 365
                        )

                        let hasKnownPrice = history.contains { $0.price != nil }
                        return hasKnownPrice ? fuel : nil
                    }
                }

                var result = Set<FuelType>()

                for try await fuel in group {
                    if let fuel {
                        result.insert(fuel)
                    }
                }

                return result
            }

            let merged = fuelsKnownAtOpen.union(fuelsWithHistory)
            let ordered = FuelType.allCases.filter { merged.contains($0) }

            await MainActor.run {
                resolvedFuelTypes = ordered
                hasLoadedResolvedFuelTypes = true
                isLoadingResolvedFuelTypes = false
            }
        } catch {
            print("Erreur chargement carburants résolus:", error)

            await MainActor.run {
                resolvedFuelTypes = initiallyKnownFuels
                hasLoadedResolvedFuelTypes = true
                isLoadingResolvedFuelTypes = false
            }
        }
    }

    private var initiallyKnownFuels: [FuelType] {
        FuelType.allCases.filter {
            station.price(for: $0) != nil || initiallyResolvedFuelTypes.contains($0)
        }
    }

    private func stationHasConfirmedFuel(_ fuel: FuelType) -> Bool {
        displayedFuels.contains(fuel)
    }
    
//    private var displayedFuels: [FuelType] {
//        if !resolvedFuelTypes.isEmpty {
//            return resolvedFuelTypes
//        }
//
//        return FuelType.allCases.filter { station.price(for: $0) != nil }
//    }
//
//    private var historyFuels: [FuelType] {
//        displayedFuels
//    }
//
//    private var alertableFuels: [FuelType] {
//        displayedFuels
//    }

    private func activateAlert(for fuelType: FuelType) async {
        guard !isSubmittingAlert else { return }

        isSubmittingAlert = true
        defer { isSubmittingAlert = false }

        do {
            _ = try await alertManager.activateAlert(
                stationID: station.id,
                fuelType: fuelType.rawValue,
                stationName: station.displayName
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

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(UrbanTheme.frost)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
                .bold()
                .foregroundStyle(UrbanTheme.textPrimary)
        }
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

    private func formattedPricePerLiter(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)) €/L"
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    private func formattedDistance(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value < 10 ? 1 : 0
        formatter.maximumFractionDigits = value < 10 ? 1 : 0
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)) km"
    }

    private func formattedSpeed(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.maximumFractionDigits = 1
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(text) km/h"
    }
}

private struct AutonomyEstimatorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let vehicle: VehicleProfile
    let station: FuelStation
    let onEstimate: (FillEstimation) -> Void

    @State private var distanceText = ""
    @State private var averageConsumptionText = ""
    @State private var remainingRangeText = ""
    @State private var averageSpeedText = ""

    private var stationPrice: Double? {
        station.price(for: vehicle.fuelType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Véhicule") {
                    infoRow(title: "Véhicule", value: vehicle.label)
                    infoRow(title: "Carburant", value: vehicle.fuelType.displayName)
                    infoRow(title: "Réservoir", value: formattedLiters(vehicle.tankCapacityLiters))
                    infoRow(title: "Conso de référence", value: formattedConsumption(vehicle.consumptionLitersPer100km))

                    if let stationPrice {
                        infoRow(title: "Prix station", value: formattedPricePerLiter(stationPrice))
                    }
                }

                Section("Ordinateur de bord") {
                    TextField("Distance parcourue depuis le dernier plein (km)", text: $distanceText)
                        .keyboardType(.decimalPad)

                    TextField("Consommation moyenne affichée (L/100)", text: $averageConsumptionText)
                        .keyboardType(.decimalPad)

                    TextField("Autonomie restante estimée (km)", text: $remainingRangeText)
                        .keyboardType(.decimalPad)

                    TextField("Vitesse moyenne (km/h) - optionnel", text: $averageSpeedText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text("Ces informations peuvent être relevées sur le tableau de bord en appuyant sur le bouton « << » du commodo d’essuie-glace, si l’ordinateur de bord a bien été réinitialisé après chaque plein.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Estimer le plein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Calculer") {
                        calculate()
                    }
                    .disabled(!canCalculate)
                }
            }
            .onAppear {
            }
        }
    }

    private var parsedDistance: Double? {
        parseDecimal(distanceText)
    }

    private var parsedAverageConsumption: Double? {
        parseDecimal(averageConsumptionText)
    }

    private var parsedRemainingRange: Double? {
        parseDecimal(remainingRangeText)
    }

    private var parsedAverageSpeed: Double? {
        parseOptionalDecimal(averageSpeedText)
    }

    private var canCalculate: Bool {
        guard stationPrice != nil else { return false }
        guard let parsedDistance, parsedDistance > 0 else { return false }
        guard let parsedAverageConsumption, parsedAverageConsumption > 0 else { return false }
        guard let parsedRemainingRange, parsedRemainingRange >= 0 else { return false }
        return true
    }

    private func calculate() {
        guard let price = stationPrice,
              let distanceKm = parsedDistance,
              let averageConsumption = parsedAverageConsumption,
              let remainingRangeKm = parsedRemainingRange else {
            return
        }

        let usedLitersByDistance = max((distanceKm / 100.0) * averageConsumption, 0)

        let remainingLitersByRange = max((remainingRangeKm / 100.0) * averageConsumption, 0)

        let estimatedLitersToAdd: Double

        if remainingLitersByRange >= vehicle.tankCapacityLiters {
            estimatedLitersToAdd = min(usedLitersByDistance, vehicle.tankCapacityLiters)
        } else {
            estimatedLitersToAdd = min(
                max(vehicle.tankCapacityLiters - remainingLitersByRange, 0),
                vehicle.tankCapacityLiters
            )
        }

        let estimation = FillEstimation(
            distanceKm: distanceKm,
            averageConsumptionLitersPer100km: averageConsumption,
            remainingRangeKm: remainingRangeKm,
            averageSpeedKmh: parsedAverageSpeed,
            currentFuelLiters: min(remainingLitersByRange, vehicle.tankCapacityLiters),
            tankCapacityLiters: vehicle.tankCapacityLiters,
            pricePerLiter: price,
            estimatedLitersToAdd: estimatedLitersToAdd,
            estimatedFillCost: estimatedLitersToAdd * price
        )

        onEstimate(estimation)
        dismiss()
    }

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized)
    }

    private func parseOptionalDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return parseDecimal(trimmed)
    }

    private func decimalString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
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

    private func formattedPricePerLiter(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)) €/L"
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FillEstimation {
    let distanceKm: Double
    let averageConsumptionLitersPer100km: Double
    let remainingRangeKm: Double
    let averageSpeedKmh: Double?
    let currentFuelLiters: Double
    let tankCapacityLiters: Double
    let pricePerLiter: Double
    let estimatedLitersToAdd: Double
    let estimatedFillCost: Double

    var fillLevelOptions: [FillLevelEstimate] {
        [
            FillLevelEstimate(title: "1/4 plein", fraction: 0.25, currentFuelLiters: currentFuelLiters, tankCapacityLiters: tankCapacityLiters, pricePerLiter: pricePerLiter),
            FillLevelEstimate(title: "1/2 plein", fraction: 0.50, currentFuelLiters: currentFuelLiters, tankCapacityLiters: tankCapacityLiters, pricePerLiter: pricePerLiter),
            FillLevelEstimate(title: "3/4 plein", fraction: 0.75, currentFuelLiters: currentFuelLiters, tankCapacityLiters: tankCapacityLiters, pricePerLiter: pricePerLiter),
            FillLevelEstimate(title: "Plein complet", fraction: 1.00, currentFuelLiters: currentFuelLiters, tankCapacityLiters: tankCapacityLiters, pricePerLiter: pricePerLiter)
        ]
    }
}

private struct FillLevelEstimate: Identifiable {
    let title: String
    let fraction: Double
    let currentFuelLiters: Double
    let tankCapacityLiters: Double
    let pricePerLiter: Double

    var id: Double { fraction }

    var litersToAdd: Double {
        max((tankCapacityLiters * fraction) - currentFuelLiters, 0)
    }

    var cost: Double {
        litersToAdd * pricePerLiter
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
