import Foundation
import Combine

@MainActor
final class SavedPlacesStore: ObservableObject {
    static let shared = SavedPlacesStore()

    @Published private(set) var places: [SavedPlace] = []

    private let storageKey = "saved_places"

    private init() {
        load()
    }

    func addPlace(name: String, latitude: Double, longitude: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        places.append(
            SavedPlace(
                name: trimmedName,
                latitude: latitude,
                longitude: longitude
            )
        )
        places.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }

    func deletePlaces(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            places.remove(at: offset)
        }
        save()
    }

    func removePlace(_ place: SavedPlace) {
        places.removeAll { $0.id == place.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            places = []
            return
        }

        do {
            places = try JSONDecoder().decode([SavedPlace].self, from: data)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Impossible de relire les lieux enregistrés :", error.localizedDescription)
            places = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(places)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Impossible de sauvegarder les lieux enregistrés :", error.localizedDescription)
        }
    }
}
