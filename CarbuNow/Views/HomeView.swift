import SwiftUI
import MapKit
import CoreLocation

private let defaultHomeRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 44.555, longitude: -0.245),
    span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
)

struct HomeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var viewModel: StationsViewModel

    @State private var selectedStation: FuelStation?
    @State private var region = defaultHomeRegion
    @State private var appliedRegion = defaultHomeRegion
    @State private var cameraPosition: MapCameraPosition = .region(defaultHomeRegion)
    @State private var didAutoCenterOnUser = false
    @State private var hasPendingMapRefresh = false
    @State private var lastListReloadLocation: CLLocation?
    @State private var didInitialListLoad = false
    @State private var showCitySearchSheet = false
    @State private var citySearchText = ""
    @State private var isSearchingCity = false
    @State private var citySearchErrorMessage: String?
    @State private var suppressNextPendingRefresh = false

    var body: some View {
        TabView {
            NavigationStack {
                mapContent
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                showCitySearchSheet = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }

                            Button {
                                Task {
                                    appliedRegion = region
                                    hasPendingMapRefresh = false
                                    suppressNextPendingRefresh = true
                                    await viewModel.loadStations(in: appliedRegion, force: true)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }

                            Button {
                                locationManager.requestPermission()
                                locationManager.startUpdating()
                                recenterOnUserIfPossible(force: true)
                            } label: {
                                Image(systemName: "location.fill")
                            }
                        }
                    }
                    .sheet(isPresented: $showCitySearchSheet) {
                        citySearchSheet
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
            }
            .tabItem {
                Label("Carte", systemImage: "map.fill")
            }

            NavigationStack {
                listContent
                    .navigationTitle("Stations")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task {
                                    await reloadList(force: true)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Liste", systemImage: "list.bullet")
            }

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape.fill")
                }
        }
        .task {
            await viewModel.loadStations(in: appliedRegion, force: true)
            await reloadList(force: true)
        }
        .onAppear {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else {
                locationManager.startUpdating()
            }
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            recenterOnUserIfPossible(force: false)

            guard shouldReloadList(for: newLocation) else { return }

            Task {
                await reloadList(force: false)
            }
        }
        .onChange(of: viewModel.selectedFuel) { _, _ in
            Task {
                await viewModel.loadStations(in: appliedRegion, force: true)
                await reloadList(force: true)
            }
        }
        .onChange(of: viewModel.searchRadiusKm) { _, _ in
            Task {
                await reloadList(force: true)
            }
        }
        .sheet(item: $selectedStation) { station in
            NavigationStack {
                StationDetailView(
                    station: station,
                    showsCloseButton: true
                )
            }
        }
        .alert("Recherche impossible", isPresented: Binding(
            get: { citySearchErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    citySearchErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                citySearchErrorMessage = nil
            }
        } message: {
            Text(citySearchErrorMessage ?? "")
        }
    }

    private var mapContent: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(mapStations) { station in
                    Annotation(station.displayName, coordinate: station.coordinate) {
                        stationAnnotationView(for: station)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                region = context.region
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Spacer()

                    if hasPendingMapRefresh {
                        Button {
                            Task {
                                suppressNextPendingRefresh = true
                                appliedRegion = region
                                hasPendingMapRefresh = false
                                await viewModel.loadStations(in: appliedRegion, force: true)
                            }
                        } label: {
                            Label("Actualiser la zone", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                mapFuelSection
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
        }
        .onChange(of: regionSnapshot) { _, _ in
            if suppressNextPendingRefresh {
                suppressNextPendingRefresh = false
                hasPendingMapRefresh = false
                return
            }

            guard didAutoCenterOnUser else {
                hasPendingMapRefresh = false
                return
            }

            hasPendingMapRefresh = regionDifferenceIsSignificant(lhs: region, rhs: appliedRegion)
        }
    }

    private var citySearchSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rechercher une ville")
                    .font(.title3.bold())

                TextField("Ex : Bordeaux, Toulouse, Paris...", text: $citySearchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await searchCityAndRefresh()
                        }
                    }

                Button {
                    Task {
                        await searchCityAndRefresh()
                    }
                } label: {
                    HStack {
                        if isSearchingCity {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }

                        Text(isSearchingCity ? "Recherche..." : "Rechercher")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearchingCity || citySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("La carte sera déplacée automatiquement sur la ville trouvée, puis la zone sera actualisée.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Recherche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        showCitySearchSheet = false
                    }
                }
            }
        }
    }

    private func stationAnnotationView(for station: FuelStation) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "fuelpump.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(4)
                .background(priceColorForMap(for: station))
                .clipShape(Circle())
                .shadow(radius: 4)

            if let price = station.price(for: viewModel.selectedFuel) {
                Text(String(format: "%.3f €", price))
                    .font(.caption2.bold())
                    .foregroundStyle(priceColorForMap(for: station))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(
            Color.black.opacity(0.001)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                selectedStation = station
            }
        )
    }

    private var listContent: some View {
        VStack(spacing: 12) {
            listFiltersSection

            if viewModel.isListLoading {
                Spacer()
                ProgressView("Chargement des stations...")
                Spacer()
            } else if let errorMessage = viewModel.listErrorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                    Text("Erreur")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    if let lastRefreshDate = viewModel.lastListRefreshDate {
                        Text("Dernière synchro : \(formattedDate(lastRefreshDate))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.filteredAndSortedListStations(userLocation: locationManager.currentLocation)) { station in
                        NavigationLink {
                            StationDetailView(station: station)
                        } label: {
                            StationRowView(
                                station: station,
                                selectedFuel: viewModel.selectedFuel,
                                userLocation: locationManager.currentLocation,
                                priceColor: priceColorForList(for: station)
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await reloadList(force: true)
                }
            }
        }
    }

    private var mapFuelSection: some View {
        VStack(spacing: 10) {
            Picker("Carburant", selection: Binding(
                get: { viewModel.selectedFuel },
                set: { viewModel.setDefaultFuel($0) }
            )) {
                ForEach(FuelType.allCases) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var listFiltersSection: some View {
        VStack(spacing: 10) {
            Picker("Carburant", selection: Binding(
                get: { viewModel.selectedFuel },
                set: { viewModel.setDefaultFuel($0) }
            )) {
                ForEach(FuelType.allCases) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tri", selection: $viewModel.sortOption) {
                ForEach(StationSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Rayon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(viewModel.searchRadiusKm)) km")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var mapStations: [FuelStation] {
        let latMin = appliedRegion.center.latitude - appliedRegion.span.latitudeDelta * 0.55
        let latMax = appliedRegion.center.latitude + appliedRegion.span.latitudeDelta * 0.55
        let lonMin = appliedRegion.center.longitude - appliedRegion.span.longitudeDelta * 0.55
        let lonMax = appliedRegion.center.longitude + appliedRegion.span.longitudeDelta * 0.55

        let insideRegion = viewModel.filteredAndSortedStations(
            userLocation: locationManager.currentLocation,
            radiusKm: 0
        ).filter { station in
            station.latitude >= latMin && station.latitude <= latMax &&
            station.longitude >= lonMin && station.longitude <= lonMax
        }

        let limit: Int
        let maxSpan = max(appliedRegion.span.latitudeDelta, appliedRegion.span.longitudeDelta)
        switch maxSpan {
        case 0..<0.03:
            limit = 30
        case 0.03..<0.06:
            limit = 24
        case 0.06..<0.12:
            limit = 16
        default:
            limit = 12
        }

        return Array(insideRegion.prefix(limit))
    }

    private var regionSnapshot: String {
        let c = region.center
        let s = region.span
        return "\(c.latitude)|\(c.longitude)|\(s.latitudeDelta)|\(s.longitudeDelta)"
    }

    private func recenterOnUserIfPossible(force: Bool) {
        guard let currentLocation = locationManager.currentLocation else { return }
        if !force && didAutoCenterOnUser { return }

        didAutoCenterOnUser = true
        suppressNextPendingRefresh = true

        let nextRegion = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )

        region = nextRegion
        appliedRegion = nextRegion
        cameraPosition = .region(nextRegion)
        hasPendingMapRefresh = false

        Task {
            await viewModel.loadStations(in: appliedRegion, force: true)
        }
    }

    private func shouldReloadList(for newLocation: CLLocation?) -> Bool {
        guard let newLocation else { return false }

        if !didInitialListLoad {
            return true
        }

        guard let lastListReloadLocation else {
            return true
        }

        return newLocation.distance(from: lastListReloadLocation) >= 250
    }

    private func reloadList(force: Bool) async {
        await viewModel.loadListStations(
            userLocation: locationManager.currentLocation,
            force: force
        )

        if let currentLocation = locationManager.currentLocation {
            lastListReloadLocation = currentLocation
            didInitialListLoad = true
        }
    }

    private func searchCityAndRefresh() async {
        let trimmedQuery = citySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        isSearchingCity = true
        defer { isSearchingCity = false }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmedQuery
            request.resultTypes = .address

            let response = try await MKLocalSearch(request: request).start()

            guard let firstItem = response.mapItems.first else {
                citySearchErrorMessage = "Aucun résultat trouvé pour “\(trimmedQuery)”."
                return
            }

            let nextRegion: MKCoordinateRegion
            let responseRegion = response.boundingRegion
            let hasUsableSpan = responseRegion.span.latitudeDelta > 0 && responseRegion.span.longitudeDelta > 0

            if hasUsableSpan {
                let adjustedLat = max(responseRegion.span.latitudeDelta * 1.4, 0.08)
                let adjustedLon = max(responseRegion.span.longitudeDelta * 1.4, 0.08)

                nextRegion = MKCoordinateRegion(
                    center: responseRegion.center,
                    span: MKCoordinateSpan(latitudeDelta: adjustedLat, longitudeDelta: adjustedLon)
                )
            } else {
                let coordinate = firstItem.location.coordinate

                nextRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                )
            }

            suppressNextPendingRefresh = true
            didAutoCenterOnUser = true
            region = nextRegion
            appliedRegion = nextRegion
            cameraPosition = .region(nextRegion)
            hasPendingMapRefresh = false

            await viewModel.loadStations(in: appliedRegion, force: true)

            showCitySearchSheet = false
        } catch {
            citySearchErrorMessage = "Erreur pendant la recherche : \(error.localizedDescription)"
        }
    }

    private func regionDifferenceIsSignificant(lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        let centerDeltaLat = abs(lhs.center.latitude - rhs.center.latitude)
        let centerDeltaLon = abs(lhs.center.longitude - rhs.center.longitude)
        let spanDeltaLat = abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta)
        let spanDeltaLon = abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta)

        return centerDeltaLat > 0.002 || centerDeltaLon > 0.002 || spanDeltaLat > 0.002 || spanDeltaLon > 0.002
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func priceColorForMap(for station: FuelStation) -> Color {
        let prices = mapStations.compactMap { $0.price(for: viewModel.selectedFuel) }

        guard let currentPrice = station.price(for: viewModel.selectedFuel),
              let minPrice = prices.min(),
              let maxPrice = prices.max() else {
            return .green
        }

        guard maxPrice > minPrice else {
            return .green
        }

        let ratio = (currentPrice - minPrice) / (maxPrice - minPrice)
        let hue = (1 - ratio) * 0.33
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }

    private func priceColorForList(for station: FuelStation) -> Color {
        let prices = viewModel.filteredAndSortedListStations(userLocation: locationManager.currentLocation)
            .compactMap { $0.price(for: viewModel.selectedFuel) }

        guard let currentPrice = station.price(for: viewModel.selectedFuel),
              let minPrice = prices.min(),
              let maxPrice = prices.max() else {
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
