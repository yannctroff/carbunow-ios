import SwiftUI
import MapKit
import CoreLocation
import UIKit

private let defaultHomeRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 44.555, longitude: -0.245),
    span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
)

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var viewModel: StationsViewModel
    @StateObject private var notificationInbox = NotificationInboxStore.shared
    @StateObject private var citySearchCompleter = FranceAddressSearchCompleter()

    @Namespace private var mapScope

    @State private var selectedStation: FuelStation?
    @State private var selectedListStation: FuelStation?
    @State private var region = defaultHomeRegion
    @State private var appliedRegion = defaultHomeRegion
    @State private var selectedTab: HomeTab = .map
    @State private var transitionDirection: HorizontalDirection = .rightToLeft
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
    @State private var showNotificationCenterSheet = false
    @State private var showActiveAlertsSheet = false
    @State private var citySearchText = ""
    @State private var isSearchingCity = false
    @State private var citySearchErrorMessage: String?
    @State private var suppressNextPendingRefresh = false
    @State private var knownSoldFuelKeys: Set<String> = []
    @State private var knownAbsentFuelKeys: Set<String> = []
    @State private var loadingSoldFuelKeys: Set<String> = []
    @State private var openingStationIDs: Set<String> = []

    
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                mapScreen
                    .opacity(selectedTab == .map ? 1 : 0)
                    .allowsHitTesting(selectedTab == .map)
                    .zIndex(selectedTab == .map ? 1 : 0)

                if selectedTab == .list {
                    listScreen
                        .transition(screenTransition)
                        .zIndex(1)
                }

                if selectedTab == .settings {
                    settingsScreen
                        .transition(screenTransition)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            navigationDock
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(UrbanTheme.accent)
        .background(UrbanTheme.background.ignoresSafeArea())
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.26), value: selectedTab)
        .onAppear {
            locationManager.requestPermission()
            notificationInbox.pruneExpired()

            Task {
                await notificationInbox.syncDeliveredNotifications()
            }
        }
        .sheet(isPresented: $showActiveAlertsSheet) {
            NavigationStack {
                ActiveAlertsListView(showsCloseButton: true)
                    .environmentObject(viewModel)
            }
        }
        .sheet(item: $selectedListStation) { station in
            NavigationStack {
                StationDetailView(
                    station: station,
                    showsCloseButton: true,
                    initiallyResolvedFuelTypes: confirmedFuelTypes(for: station)
                )
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private var mapScreen: some View {
        mapContent
            .sheet(isPresented: $showCitySearchSheet) {
                citySearchSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotificationCenterSheet) {
                NavigationStack {
                    NotificationCenterSheetView(inbox: notificationInbox)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedStation) { station in
                NavigationStack {
                    StationDetailView(
                        station: station,
                        showsCloseButton: true,
                        initiallyResolvedFuelTypes: confirmedFuelTypes(for: station)
                    )
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }

    private var listScreen: some View {
        listContent
            .task {
                await handleInitialListLoad()
            }
            .refreshable {
                await reloadList(force: true)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var settingsScreen: some View {
        SettingsView(hidesNavigationChrome: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }

    private var navigationDock: some View {
        HStack(spacing: 10) {
            navigationButton(for: .map, title: "Carte", systemImage: "map.fill")
            navigationButton(for: .list, title: "Liste", systemImage: "list.bullet")
            navigationButton(for: .settings, title: "Réglages", systemImage: "gearshape.fill")
        }
    }

    private func navigationButton(for tab: HomeTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard selectedTab != tab else { return }
            transitionDirection = tab.index > selectedTab.index ? .rightToLeft : .leftToRight
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: isSelected ? 16 : 15, weight: .black))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.86) : UrbanTheme.mist)
            .frame(width: isSelected ? 104 : 88)
            .padding(.vertical, isSelected ? 13 : 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? UrbanTheme.accent : UrbanTheme.panel.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.clear : UrbanTheme.line, lineWidth: 1)
                    )
            )
            .shadow(
                color: isSelected ? UrbanTheme.accent.opacity(0.22) : .black.opacity(0.18),
                radius: isSelected ? 14 : 10,
                y: 6
            )
            .scaleEffect(isSelected ? 1 : 0.96)
        }
        .buttonStyle(.plain)
    }

    private var screenTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ScreenShiftModifier(offsetX: transitionDirection.insertionOffset, opacity: 0),
                identity: ScreenShiftModifier(offsetX: 0, opacity: 1)
            ),
            removal: .modifier(
                active: ScreenShiftModifier(offsetX: transitionDirection.removalOffset, opacity: 0),
                identity: ScreenShiftModifier(offsetX: 0, opacity: 1)
            )
        )
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            VStack(spacing: 12) {
                if let refreshDate = viewModel.lastRefreshDate {
                    Text("Dernière actualisation : \(formattedDate(refreshDate))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(UrbanTheme.mist)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(UrbanTheme.panel.opacity(0.92))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(UrbanTheme.line, lineWidth: 1)
                                )
                        )
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
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(UrbanCTAButtonStyle(tint: UrbanTheme.accent))
                        .padding(.trailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }

                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        mapFuelMenuButton

                        Button {
                            notificationInbox.pruneExpired()
                            notificationInbox.markAllAsSeen()

                            Task {
                                await notificationInbox.syncDeliveredNotifications(markNewAsUnread: false)
                            }

                            showNotificationCenterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(width: 16, height: 16)
                                    .padding(8)

                                if notificationInbox.unreadCount > 0 {
                                    Text(notificationInbox.unreadCount > 99 ? "99+" : "\(notificationInbox.unreadCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(UrbanTheme.textPrimary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(UrbanTheme.danger, in: Capsule())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .buttonStyle(UrbanFloatingButtonStyle(tint: UrbanTheme.panelSoft))

                        Button {
                            recenterOnUserIfPossible(force: true)
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 16, height: 16)
                                .padding(8)
                        }
                        .buttonStyle(UrbanFloatingButtonStyle(tint: UrbanTheme.panel))

                        Button {
                            showCitySearchSheet = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 16, height: 16)
                                .padding(8)
                        }
                        .buttonStyle(UrbanFloatingButtonStyle(tint: UrbanTheme.panel))
                    }
                    .padding(.trailing)
                    .padding(.bottom, 78)
                }
            }
            .safeAreaPadding(.top, 58)
        }
        .task(id: ruptureLookupKey) {
            await refreshRuptureFuelKnowledgeIfNeeded()
        }
    }

    private var mapFuelMenuButton: some View {
        Menu {
            ForEach(FuelType.allCases, id: \.self) { fuel in
                Button {
                    viewModel.setDefaultFuel(fuel)
                } label: {
                    Label(
                        fuel.displayName,
                        systemImage: fuel == viewModel.selectedFuel ? "checkmark" : "fuelpump"
                    )
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 16, height: 16)

                Text(viewModel.selectedFuel.displayName)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 36, height: 36)
            .padding(5)
        }
        .buttonStyle(
            UrbanFloatingButtonStyle(
                tint: viewModel.selectedFuel.urbanAccent,
                foreground: UrbanTheme.textPrimary
            )
        )
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
                    .fill(UrbanTheme.panel.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(UrbanTheme.line, lineWidth: 1)
            )
            .tint(viewModel.selectedFuel.urbanAccent)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private func stationAnnotationView(for station: FuelStation, color: Color) -> some View {
        let price = station.price(for: viewModel.selectedFuel)
        let isRupture = shouldShowMapRupture(for: station, fuel: viewModel.selectedFuel, price: price)
        let isPriceUnavailable = !isRupture && price == nil
        let markerFill = markerBackgroundColor(isUnavailable: isPriceUnavailable, isRupture: isRupture)
        let markerFrame = markerFrame(for: station)

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: markerFrame.height / 2, style: .continuous)
                    .fill(markerFill)
                    .frame(width: markerFrame.width, height: markerFrame.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: markerFrame.height / 2, style: .continuous)
                            .stroke(UrbanTheme.line.opacity(colorScheme == .dark ? 0.9 : 0.45), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 5, y: 3)

                brandMarkerContent(for: station)
            }

            Group {
                if isRupture {
                    annotationBadge("Rupture", tint: UrbanTheme.danger, foreground: .white)
                } else if let price {
                    annotationBadge(String(format: "%.3f €", price), tint: color, foreground: priceBadgeForeground)
                } else {
                    annotationBadge("—", tint: UrbanTheme.panel, foreground: UrbanTheme.textPrimary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await openStationDetail(station)
            }
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    @ViewBuilder
    private func brandMarkerContent(for station: FuelStation) -> some View {
        if let brand = station.normalizedBrand, UIImage(named: brand.logoAssetName) != nil {
            let logoFrame = markerLogoFrame(for: brand)

            Image(brand.logoAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: logoFrame.width, height: logoFrame.height)
        } else {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(UrbanTheme.textPrimary)
        }
    }

    private func markerFrame(for station: FuelStation) -> CGSize {
        guard station.normalizedBrand?.usesWideMapMarker == true else {
            return CGSize(width: 34, height: 34)
        }

        return CGSize(width: 52, height: 34)
    }

    private func markerLogoFrame(for brand: StationBrand) -> CGSize {
        if brand.usesWideMapMarker {
            return CGSize(width: 44, height: 18)
        }

        return CGSize(width: 27, height: 27)
    }

    private func annotationBadge(_ text: String, tint: Color, foreground: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.96 : 0.88))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.10), radius: 4, y: 2)
    }

    private func markerBackgroundColor(isUnavailable: Bool, isRupture: Bool) -> Color {
        if isUnavailable || isRupture {
            return UrbanTheme.panelSoft
        }
        return colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white
    }

    private var priceBadgeForeground: Color {
        colorScheme == .dark ? .black.opacity(0.88) : .white
    }

    private var listContent: some View {
        VStack(spacing: 12) {
            Text("Stations")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(UrbanTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 58)

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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredAndSortedListStations(userLocation: locationManager.currentLocation)) { station in
                            Button {
                                Task {
                                    await openListStationDetail(station)
                                }
                            } label: {
                                StationRowView(
                                    station: station,
                                    selectedFuel: viewModel.selectedFuel,
                                    userLocation: locationManager.currentLocation,
                                    priceColor: priceColorForList(for: station)
                                )
                                .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 124)
                }
                .scrollIndicators(.hidden)
                .background(UrbanTheme.background.ignoresSafeArea())
                .refreshable {
                    await reloadList(force: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(UrbanTheme.background.ignoresSafeArea())
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
            .tint(viewModel.selectedFuel.urbanAccent)

            Picker("Tri", selection: $viewModel.sortOption) {
                ForEach(StationSortOption.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(UrbanTheme.accentSoft)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Rayon de recherche")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(UrbanTheme.textPrimary)
                    Spacer()
                    Text(viewModel.searchRadiusKm <= 0 ? "Illimité" : "\(Int(viewModel.searchRadiusKm)) km")
                        .foregroundStyle(UrbanTheme.mist)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.searchRadiusKm },
                        set: { viewModel.setSearchRadius($0) }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(UrbanTheme.accent)
            }

            Button {
                Task {
                    await reloadList(force: true)
                }
                } label: {
                    Label("Actualiser la liste", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
            .buttonStyle(UrbanCTAButtonStyle())
            
            if let refreshDate = viewModel.lastListRefreshDate {
                Text("Dernière actualisation : \(formattedDate(refreshDate))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(UrbanTheme.frost)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(UrbanTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(UrbanTheme.line, lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var citySearchSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Adresse, ville ou code postal en France", text: $citySearchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .onChange(of: citySearchText) { _, newValue in
                        citySearchCompleter.update(query: newValue)
                    }

                if let citySearchErrorMessage {
                    Text(citySearchErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !citySearchCompleter.completions.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(citySearchCompleter.completions, id: \.completionIdentifier) { completion in
                                Button {
                                    citySearchText = completion.displayTitle
                                    Task {
                                        await searchCity(completion: completion)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(completion.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }

                Button {
                    Task {
                        await searchCity(completion: nil)
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
            .navigationTitle("Rechercher en France")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCitySearchSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                citySearchCompleter.update(query: citySearchText)
            }
            .onDisappear {
                citySearchCompleter.clear()
            }
        }
    }

    private func handleInitialLoad() async {
        guard !hasCompletedInitialMapLoad else { return }
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

    private func searchCity(completion: MKLocalSearchCompletion?) async {
        let query = citySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard completion != nil || !query.isEmpty else { return }

        isSearchingCity = true
        citySearchErrorMessage = nil
        defer { isSearchingCity = false }

        do {
            let results: [MKMapItem]
            if let completion {
                results = try await FranceAddressSearchCompleter.search(completion: completion)
            } else {
                results = try await FranceAddressSearchCompleter.search(query: query)
            }

            guard let item = results.first else {
                citySearchErrorMessage = "Aucun résultat en France."
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
            citySearchCompleter.clear()

            await viewModel.loadStations(in: searchedRegion, force: true)
            hasCompletedInitialMapLoad = true
        } catch {
            citySearchErrorMessage = "Recherche impossible ou aucun résultat en France."
        }
    }

    private var visibleMapStations: [FuelStation] {
        Array(mapRegionStations.filter(shouldShowStationOnMap).prefix(mapStationDisplayLimit))
    }

    private var mapRegionStations: [FuelStation] {
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

        return insideRegion
    }

    private var mapStationDisplayLimit: Int {
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

        return limit
    }

    private var visibleMapPrices: [Double] {
        visibleMapStations.compactMap { $0.price(for: viewModel.selectedFuel) }
    }

    private var ruptureLookupKey: String {
        let stationIDs = mapRegionStations
            .filter {
                $0.price(for: viewModel.selectedFuel) == nil &&
                $0.hasActiveRupture(for: viewModel.selectedFuel)
            }
            .map(\.id)
            .joined(separator: "|")

        return "\(viewModel.selectedFuel.rawValue)|\(stationIDs)"
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

    private func soldFuelKey(stationID: String, fuel: FuelType) -> String {
        "\(stationID)|\(fuel.rawValue)"
    }

    private func shouldShowMapRupture(for station: FuelStation, fuel: FuelType, price: Double?) -> Bool {
        guard station.hasActiveRupture(for: fuel) else { return false }

        if price != nil {
            return true
        }

        let key = soldFuelKey(stationID: station.id, fuel: fuel)
        return !knownAbsentFuelKeys.contains(key)
    }

    private func shouldShowStationOnMap(_ station: FuelStation) -> Bool {
        let fuel = viewModel.selectedFuel

        guard station.price(for: fuel) == nil, station.hasActiveRupture(for: fuel) else {
            return true
        }

        let key = soldFuelKey(stationID: station.id, fuel: fuel)
        return !knownAbsentFuelKeys.contains(key)
    }

    private func refreshRuptureFuelKnowledgeIfNeeded() async {
        let fuel = viewModel.selectedFuel
        let candidates = mapRegionStations.filter {
            $0.price(for: fuel) == nil &&
            $0.hasActiveRupture(for: fuel)
        }

        for station in candidates {
            let key = soldFuelKey(stationID: station.id, fuel: fuel)

            guard !knownSoldFuelKeys.contains(key),
                  !knownAbsentFuelKeys.contains(key),
                  !loadingSoldFuelKeys.contains(key) else {
                continue
            }

            _ = await resolveSoldFuelStatus(stationID: station.id, fuel: fuel)
        }
    }

    private func openStationDetail(_ station: FuelStation) async {
        guard !openingStationIDs.contains(station.id) else { return }

        openingStationIDs.insert(station.id)
        defer { openingStationIDs.remove(station.id) }

        await resolveActiveRuptureFuels(for: station)
        selectedStation = station
    }

    private func openListStationDetail(_ station: FuelStation) async {
        guard !openingStationIDs.contains(station.id) else { return }

        openingStationIDs.insert(station.id)
        defer { openingStationIDs.remove(station.id) }

        await resolveActiveRuptureFuels(for: station)
        selectedListStation = station
    }

    private func confirmedFuelTypes(for station: FuelStation) -> Set<FuelType> {
        Set(
            FuelType.allCases.filter { fuel in
                station.price(for: fuel) != nil ||
                knownSoldFuelKeys.contains(soldFuelKey(stationID: station.id, fuel: fuel))
            }
        )
    }

    private func resolveActiveRuptureFuels(for station: FuelStation) async {
        let fuels = FuelType.allCases.filter { fuel in
            station.price(for: fuel) == nil && station.hasActiveRupture(for: fuel)
        }

        for fuel in fuels {
            _ = await resolveSoldFuelStatus(stationID: station.id, fuel: fuel)
        }
    }

    private func resolveSoldFuelStatus(stationID: String, fuel: FuelType) async -> Bool {
        let key = soldFuelKey(stationID: stationID, fuel: fuel)

        if knownSoldFuelKeys.contains(key) { return true }
        if knownAbsentFuelKeys.contains(key) { return false }
        if loadingSoldFuelKeys.contains(key) { return false }

        loadingSoldFuelKeys.insert(key)
        defer { loadingSoldFuelKeys.remove(key) }

        do {
            let history = try await FuelAPIService.shared.fetchHistory(
                stationID: stationID,
                fuelType: fuel.rawValue,
                days: 365
            )
            let hasSoldFuel = history.contains { $0.price != nil }

            if hasSoldFuel {
                knownSoldFuelKeys.insert(key)
            } else {
                knownAbsentFuelKeys.insert(key)
            }

            return hasSoldFuel
        } catch {
            print("Historique rupture indisponible pour \(stationID) \(fuel.rawValue):", error.localizedDescription)
            return false
        }
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
        return priceScaleColor(ratio: ratio)
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
        return priceScaleColor(ratio: ratio)
    }

    private func priceScaleColor(ratio rawRatio: Double) -> Color {
        let ratio = min(max(rawRatio, 0), 1)
        let hue = (1 - ratio) * 0.33
        let saturation = colorScheme == .dark ? 0.88 : 0.82
        let brightness = colorScheme == .dark ? 0.98 : 0.78
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "carbunow" else { return }

        switch url.host?.lowercased() {
        case "alerts":
            selectedTab = .settings
            showActiveAlertsSheet = true

        case "station":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let stationID = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  !stationID.isEmpty else { return }

            let latitude = components.queryItems?.first(where: { $0.name == "lat" })?.value.flatMap(Double.init)
            let longitude = components.queryItems?.first(where: { $0.name == "lon" })?.value.flatMap(Double.init)

            Task {
                await openStationFromDeepLink(id: stationID, latitude: latitude, longitude: longitude)
            }
        default:
            break
        }
    }

    @MainActor
    private func openStationFromDeepLink(id: String, latitude: Double?, longitude: Double?) async {
        selectedTab = .map

        if let localStation = resolveStation(id: id) {
            await openStationDetail(localStation)
            return
        }

        do {
            let fetched: [FuelStation]

            if let latitude, let longitude {
                fetched = try await FuelAPIService.shared.fetchStations(
                    around: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    radiusKm: 5,
                    limit: 100
                )
            } else {
                let searchCoordinate = locationManager.currentLocation?.coordinate ?? appliedRegion.center
                fetched = try await FuelAPIService.shared.fetchStations(
                    around: searchCoordinate,
                    radiusKm: max(viewModel.searchRadiusKm, 30),
                    limit: 300
                )
            }

            if let station = fetched.first(where: { $0.id == id }) {
                await openStationDetail(station)
            }
        } catch {
            print("Impossible d'ouvrir la station depuis le widget :", error.localizedDescription)
        }
    }

    private func resolveStation(id: String) -> FuelStation? {
        let merged = viewModel.allStations + viewModel.listStations
        return merged.first(where: { $0.id == id })
    }
}

private enum HomeTab: Hashable {
    case map
    case list
    case settings

    var index: Int {
        switch self {
        case .map: return 0
        case .list: return 1
        case .settings: return 2
        }
    }
}

private enum HorizontalDirection {
    case leftToRight
    case rightToLeft

    var insertionOffset: CGFloat {
        switch self {
        case .leftToRight:
            return -26
        case .rightToLeft:
            return 26
        }
    }

    var removalOffset: CGFloat {
        switch self {
        case .leftToRight:
            return 26
        case .rightToLeft:
            return -26
        }
    }
}

private struct ScreenShiftModifier: ViewModifier {
    let offsetX: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .opacity(opacity)
    }
}

private struct NotificationCenterSheetView: View {
    @ObservedObject var inbox: NotificationInboxStore
    @Environment(\.dismiss) private var dismiss
    private let actionWidth: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            notificationHeader

            Group {
                if inbox.items.isEmpty {
                    ContentUnavailableView(
                        "Aucune notification recente",
                        systemImage: "bell.slash",
                        description: Text("Les notifications recues durant les 7 derniers jours apparaitront ici.")
                    )
                } else {
                    List(inbox.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.headline)

                            if !item.message.isEmpty {
                                Text(item.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(formattedDate(item.receivedAt))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                inbox.delete(item)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            inbox.pruneExpired()
            inbox.markAllAsSeen()
            await inbox.syncDeliveredNotifications(markNewAsUnread: false)
        }
    }

    private var notificationHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Notifications")
                    .font(.headline)

                HStack {
                    Button("Fermer") {
                        dismiss()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                    .frame(width: actionWidth, alignment: .leading)

                    Spacer()

                    Button("Tout effacer") {
                        inbox.clearAll()
                    }
                    .disabled(inbox.items.isEmpty)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                    .frame(width: actionWidth, alignment: .trailing)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .full
        return date.formatted(date: .abbreviated, time: .shortened) + " • " + formatter.localizedString(for: date, relativeTo: .now)
    }
}

private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let lhs = CLLocation(latitude: latitude, longitude: longitude)
        let rhs = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return lhs.distance(from: rhs)
    }
}
