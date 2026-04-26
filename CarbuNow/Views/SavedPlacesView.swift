import SwiftUI
import MapKit
import CoreLocation

struct SavedPlacesView: View {
    @EnvironmentObject private var viewModel: StationsViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @ObservedObject private var savedPlacesStore = SavedPlacesStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false
    @State private var selectedStation: FuelStation?
    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        List {
            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Ajouter un lieu", systemImage: "plus.circle.fill")
                }

                Text("Le meilleur prix est calculé autour de chaque lieu avec le carburant par défaut et le rayon de recherche actuel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Mes lieux") {
                if savedPlacesStore.places.isEmpty {
                    ContentUnavailableView(
                        "Aucun lieu enregistré",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Ajoute Maison, Travail ou tout autre lieu pour voir rapidement les meilleurs prix autour.")
                    )
                } else {
                    ForEach(savedPlacesStore.places) { place in
                        SavedPlaceRow(
                            place: place,
                            selectedFuel: viewModel.selectedFuel,
                            radiusKm: viewModel.searchRadiusKm
                        ) { station in
                            selectedStation = station
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Supprimer", role: .destructive) {
                                savedPlacesStore.removePlace(place)
                            }
                        }
                    }
                    .onDelete(perform: savedPlacesStore.deletePlaces)
                }
            }
        }
        .navigationTitle("Mes lieux")
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
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddSavedPlaceView()
                    .environmentObject(locationManager)
            }
        }
        .sheet(item: $selectedStation) { station in
            NavigationStack {
                StationDetailView(station: station, showsCloseButton: true)
            }
        }
    }
}

private struct SavedPlaceRow: View {
    let place: SavedPlace
    let selectedFuel: FuelType
    let radiusKm: Double
    let onSelectStation: (FuelStation) -> Void

    @State private var isLoading = false
    @State private var bestStation: FuelStation?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            if let bestStation {
                onSelectStation(bestStation)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let bestStation, let price = bestStation.price(for: selectedFuel) {
                    Text(bestStation.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(selectedFuel.displayName) • \(formattedPrice(price)) • \(formattedDistance(from: place.coordinate, to: bestStation.coordinate))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Aucune station trouvée autour de ce lieu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: taskKey) {
            await loadBestStation()
        }
    }

    private var taskKey: String {
        "\(place.id.uuidString)|\(selectedFuel.rawValue)|\(radiusKm)"
    }

    private func loadBestStation() async {
        isLoading = true
        errorMessage = nil

        do {
            let stations = try await FuelAPIService.shared.fetchStations(
                around: place.coordinate,
                radiusKm: radiusKm <= 0 ? 100 : radiusKm,
                limit: 150
            )

            let filtered = stations.filter { $0.price(for: selectedFuel) != nil }

            bestStation = filtered.min {
                let lhsPrice = $0.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                let rhsPrice = $1.price(for: selectedFuel) ?? .greatestFiniteMagnitude

                if lhsPrice == rhsPrice {
                    let lhsDistance = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                        .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
                    let rhsDistance = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                        .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
                    return lhsDistance < rhsDistance
                }

                return lhsPrice < rhsPrice
            }
        } catch {
            errorMessage = "Impossible de charger les stations."
            bestStation = nil
        }

        isLoading = false
    }

    private func formattedPrice(_ price: Double) -> String {
        String(format: "%.3f €/L", price)
    }

    private func formattedDistance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> String {
        let lhs = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let rhs = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let distance = lhs.distance(from: rhs)

        if distance < 1000 {
            return "\(Int(distance)) m"
        }

        return String(format: "%.1f km", distance / 1000)
    }
}

private struct AddSavedPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @ObservedObject private var savedPlacesStore = SavedPlacesStore.shared

    @State private var placeName = ""
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Lieu") {
                TextField("Nom du lieu", text: $placeName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button {
                    useCurrentLocation()
                } label: {
                    Label("Utiliser ma position actuelle", systemImage: "location.fill")
                }
                .disabled(locationManager.currentLocation == nil)

                if let selectedMapItem {
                    Text(selectedMapItem.placemark.title ?? "Lieu sélectionné")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Rechercher un lieu") {
                TextField("Ville, quartier ou adresse", text: $searchQuery)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await searchPlaces()
                    }
                } label: {
                    HStack {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Rechercher")
                    }
                }
                .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !searchResults.isEmpty {
                    ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                        Button {
                            selectedMapItem = item
                            if placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                placeName = item.name ?? item.placemark.locality ?? "Nouveau lieu"
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Lieu")
                                    .foregroundStyle(.primary)
                                if let subtitle = item.placemark.title {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ajouter un lieu")
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
                .disabled(selectedMapItem == nil || placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func useCurrentLocation() {
        guard let currentLocation = locationManager.currentLocation else { return }

        let placemark = MKPlacemark(coordinate: currentLocation.coordinate)
        selectedMapItem = MKMapItem(placemark: placemark)

        if placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            placeName = "Mon lieu"
        }
    }

    private func searchPlaces() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
            if searchResults.isEmpty {
                errorMessage = "Aucun résultat."
            }
        } catch {
            errorMessage = "Recherche impossible ou aucun résultat."
        }
    }

    private func save() {
        guard let selectedMapItem else { return }

        let coordinate = selectedMapItem.placemark.coordinate

        savedPlacesStore.addPlace(
            name: placeName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        dismiss()
    }
}
