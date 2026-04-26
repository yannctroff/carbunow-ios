import Foundation

struct StationHistoryEntry: Identifiable, Codable, Hashable {
    let id: String
    var stationID: String
    var displayName: String
    var subtitle: String
    var updatedAtText: String?
    var latitude: Double
    var longitude: Double
    var lastViewedAt: Date
    var viewCount: Int
    var latestPrices: [String: Double]

    init(station: FuelStation, viewedAt: Date = Date()) {
        self.id = station.id
        self.stationID = station.id
        self.displayName = station.displayName
        self.subtitle = station.subtitle
        self.updatedAtText = station.updatedAtText
        self.latitude = station.latitude
        self.longitude = station.longitude
        self.lastViewedAt = viewedAt
        self.viewCount = 1
        self.latestPrices = Dictionary(
            uniqueKeysWithValues: station.prices.map { ($0.type.rawValue, $0.price) }
        )
    }
}
