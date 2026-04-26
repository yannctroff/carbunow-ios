import Foundation
import Combine

@MainActor
final class StationHistoryStore: ObservableObject {
    static let shared = StationHistoryStore()

    @Published private(set) var entries: [StationHistoryEntry] = []

    private let storageKey = "personal_station_history"
    private let maxEntries = 50

    private init() {
        load()
    }

    var recentEntries: [StationHistoryEntry] {
        entries.sorted { $0.lastViewedAt > $1.lastViewedAt }
    }

    var mostViewedEntries: [StationHistoryEntry] {
        entries.sorted {
            if $0.viewCount == $1.viewCount {
                return $0.lastViewedAt > $1.lastViewedAt
            }
            return $0.viewCount > $1.viewCount
        }
    }

    func recordView(for station: FuelStation) {
        let viewedAt = Date()

        if let index = entries.firstIndex(where: { $0.stationID == station.id }) {
            entries[index].displayName = station.displayName
            entries[index].subtitle = station.subtitle
            entries[index].updatedAtText = station.updatedAtText
            entries[index].latitude = station.latitude
            entries[index].longitude = station.longitude
            entries[index].lastViewedAt = viewedAt
            entries[index].viewCount += 1
            entries[index].latestPrices = Dictionary(
                uniqueKeysWithValues: station.prices.map { ($0.type.rawValue, $0.price) }
            )
        } else {
            entries.append(StationHistoryEntry(station: station, viewedAt: viewedAt))
        }

        entries = Array(recentEntries.prefix(maxEntries))
        save()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([StationHistoryEntry].self, from: data)
        } catch {
            print("Impossible de relire l'historique personnel :", error.localizedDescription)
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Impossible de sauvegarder l'historique personnel :", error.localizedDescription)
        }
    }
}
