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

    @Namespace private var mapScope

    @State private var selectedStation: FuelStation?
    @State private var region = defaultHomeRegion
    @State private var appliedRegion = defaultHomeRegion
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: defaultHomeRegion.center,
            distance: 18000,
            heading: 0,
            pitch: 0
        )
    )
    @State private var didAutoCenterOnUser = false
    @State private var hasPendingMapRefresh = false
    @State private var hasCompletedInitialMapLoad = false
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
                    .toolbar(.hidden, for: .navigationBar)
                    .sheet(isPresented: $showCitySearchSheet) {
                        citySearchSheet
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    .sheet(item: $selectedStation) { station in
                        NavigationStack {
                            StationDetailView(station: station, showsCloseButton: true)
                        }
                    }
                    .task {
                        await handleInitialLoad()
                    }
                    .onChange(of: locationManager.authorizationStatus) { _, _ in
                        Task {
                            await handleLocationAuthorizationChange()
                        }
                    }
                    .onChange(of: locationManager.currentLocation?.coordinate.latitude) { _, _ in
                        handleLocationChange()
                    }
                    .onChange(of: locationManager.currentLocation?.coordinate.longitude) { _, _ in
                        handleLocationChange()
                    }
                    .onChange(of: regionSnapshot) { _, _ in
                        handleRegionChange()
                    }
            }
            .tabItem {
                Label("Carte", systemImage: "map")
            }

            NavigationStack {
                listContent
                    .navigationTitle("Stations")
                    .task {
                        await handleInitialListLoad()
                    }
                    .refreshable {
                        await reloadList(force: true)
                    }
            }
            .tabItem {
                Label {
                    Text("Liste")
                        .foregroundStyle(.green)
                } icon: {
                    Image(systemName: "list.bullet")
                        .renderingMode(.template)
                        .foregroundStyle(.green)
                }
            }

            NavigationStack {
                SettingsView()
                    .navigationTitle("Paramètres")
            }
            .tabItem {
                Label {
                    Text("Paramètres")
                        .foregroundStyle(.gray)
                } icon: {
                    Image(systemName: "gearshape")
                        .renderingMode(.template)
                        .foregroundStyle(.gray)
                }
            }
        }
        .onAppear {
                locationManager.requestPermission()
            }
    }

    private var mapContent: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate], scope: mapScope) {

                UserAnnotation()

                ForEach(visibleMapStations) { station in
                    Annotation(station.displayName, coordinate: station.coordinate) {
                        stationAnnotationView(
                            for: station,
                            color: priceColorForMap(for: station, prices: visibleMapPrices)
                        )
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapScope(mapScope)
            .mapControlVisibility(.hidden)
            .onMapCameraChange(frequency: .onEnd) { context in
                region = context.region
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                mapFuelSection

                if let refreshDate = viewModel.lastRefreshDate {
                    Text("Dernière actualisation : \(formattedDate(refreshDate))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }

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
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                                .shadow(radius: 6)
                        }
                        .padding(.trailing)
                    }
                }

                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        Button {
                            recenterOnUserIfPossible(force: true)
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 6)
                        }

                        Button {
                            showCitySearchSheet = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 6)
                        }
                    }
                    .padding(.trailing)
                    .padding(.bottom, 90)
                }
            }
            .safeAreaPadding(.top, 8)
        }
    }

    private var mapFuelSection: some View {
        VStack(spacing: 10) {
            Picker("Carburant", selection: Binding(
                get: { viewModel.selectedFuel },
                set: { viewModel.setDefaultFuel($0) }
            )) {
                ForEach(FuelType.allCases, id: \.self) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private func stationAnnotationView(for station: FuelStation, color: Color) -> some View {
        let isRupture = station.shouldShowRuptureBadge(for: viewModel.selectedFuel)
        let price = station.price(for: viewModel.selectedFuel)
        let isPriceUnavailable = !isRupture && price == nil

        return VStack(spacing: 3) {
            Image(systemName: "fuelpump.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(4)
                .background((isRupture || isPriceUnavailable) ? Color.gray : color)
                .clipShape(Circle())
                .shadow(radius: 3)

            if isRupture {
                Text("Rupture")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.92))
                    )
            } else if let price {
                Text(String(format: "%.3f €", price))
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            } else {
                Text("—")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.92))
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStation = station
        }
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
                List(viewModel.filteredAndSortedListStations(userLocation: locationManager.currentLocation)) { station in
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
                .listStyle(.plain)
                .refreshable {
                    await reloadList(force: true)
                }
            }
        }
    }

    private var listFiltersSection: some View {
        VStack(spacing: 12) {
            Picker("Carburant", selection: Binding(
                get: { viewModel.selectedFuel },
                set: { viewModel.setDefaultFuel($0) }
            )) {
                ForEach(FuelType.allCases, id: \.self) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tri", selection: $viewModel.sortOption) {
                ForEach(StationSortOption.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Rayon de recherche")
                    Spacer()
                    Text(viewModel.searchRadiusKm <= 0 ? "Illimité" : "\(Int(viewModel.searchRadiusKm)) km")
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
            }

            Button {
                Task {
                    await reloadList(force: true)
                }
            } label: {
                Label("Actualiser la liste", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            if let refreshDate = viewModel.lastListRefreshDate {
                Text("Dernière actualisation : \(formattedDate(refreshDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var citySearchSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Ville ou code postal (33000, Bordeaux, 750000, Paris,...)", text: $citySearchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                if let citySearchErrorMessage {
                    Text(citySearchErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await searchCity()
                    }
                } label: {
                    HStack {
                        if isSearchingCity {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Rechercher")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearchingCity || citySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Rechercher une ville")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handleInitialLoad() async {
        recenterOnUserIfPossible(force: false)
        appliedRegion = region
        hasPendingMapRefresh = false
        await viewModel.loadStations(in: appliedRegion, force: true)
        hasCompletedInitialMapLoad = true
    }

    private func handleLocationAuthorizationChange() async {
        recenterOnUserIfPossible(force: false)
        await reloadList(force: true)
    }

    private func handleInitialListLoad() async {
        guard !didInitialListLoad else { return }
        didInitialListLoad = true
        await reloadList(force: true)
    }

    private func handleLocationChange() {
        guard let currentLocation = locationManager.currentLocation else { return }

        if !didAutoCenterOnUser {
            recenterOnUserIfPossible(force: false)
        }

        if let last = lastListReloadLocation {
            let moved = currentLocation.distance(from: last)
            if moved >= 5000 {
                Task {
                    await reloadList(force: true)
                }
            }
        } else {
            Task {
                await reloadList(force: true)
            }
        }
    }

    private func handleRegionChange() {
        guard hasCompletedInitialMapLoad else { return }

        guard !suppressNextPendingRefresh else {
            suppressNextPendingRefresh = false
            return
        }

        let distance = region.center.distance(to: appliedRegion.center)
        let latDeltaDiff = abs(region.span.latitudeDelta - appliedRegion.span.latitudeDelta)
        let lonDeltaDiff = abs(region.span.longitudeDelta - appliedRegion.span.longitudeDelta)

        if distance > 1000 || latDeltaDiff > 0.01 || lonDeltaDiff > 0.01 {
            hasPendingMapRefresh = true
        }
    }

    private func reloadList(force: Bool) async {
        await viewModel.loadListStations(
            userLocation: locationManager.currentLocation,
            force: force
        )
        lastListReloadLocation = locationManager.currentLocation
    }

    private func searchCity() async {
        let query = citySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearchingCity = true
        citySearchErrorMessage = nil
        defer { isSearchingCity = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                citySearchErrorMessage = "Aucun résultat."
                return
            }

            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            
            let searchedRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )

            suppressNextPendingRefresh = true
            region = searchedRegion
            appliedRegion = searchedRegion
            cameraPosition = cameraPosition(for: searchedRegion, distance: 12000)
            hasPendingMapRefresh = false
            showCitySearchSheet = false

            await viewModel.loadStations(in: searchedRegion, force: true)
            hasCompletedInitialMapLoad = true
        } catch {
            citySearchErrorMessage = error.localizedDescription
        }
    }

    private var visibleMapStations: [FuelStation] {
        let latMin = appliedRegion.center.latitude - appliedRegion.span.latitudeDelta / 2
        let latMax = appliedRegion.center.latitude + appliedRegion.span.latitudeDelta / 2
        let lonMin = appliedRegion.center.longitude - appliedRegion.span.longitudeDelta / 2
        let lonMax = appliedRegion.center.longitude + appliedRegion.span.longitudeDelta / 2

        let candidates = viewModel.filteredAndSortedStations(
            userLocation: locationManager.currentLocation,
            radiusKm: 0
        )
        let insideRegion = candidates.filter { station in
            station.latitude >= latMin && station.latitude <= latMax &&
            station.longitude >= lonMin && station.longitude <= lonMax
        }

        let limit: Int
        let maxSpan = max(appliedRegion.span.latitudeDelta, appliedRegion.span.longitudeDelta)

        switch maxSpan {
        case 0..<0.03:
            limit = 40
        case 0.03..<0.06:
            limit = 28
        case 0.06..<0.12:
            limit = 18
        case 0.12..<0.25:
            limit = 12
        default:
            limit = 8
        }

        return Array(insideRegion.prefix(limit))
    }

    private var visibleMapPrices: [Double] {
        visibleMapStations.compactMap { $0.price(for: viewModel.selectedFuel) }
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

        let newRegion = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )

        region = newRegion
        appliedRegion = newRegion
        cameraPosition = cameraPosition(for: newRegion, distance: 12000)
        hasPendingMapRefresh = false
    }

    private func cameraPosition(for region: MKCoordinateRegion, distance: CLLocationDistance) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: region.center,
                distance: distance,
                heading: 0,
                pitch: 0
            )
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func priceColorForMap(for station: FuelStation, prices: [Double]) -> Color {
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

private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let lhs = CLLocation(latitude: latitude, longitude: longitude)
        let rhs = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return lhs.distance(from: rhs)
    }
}
