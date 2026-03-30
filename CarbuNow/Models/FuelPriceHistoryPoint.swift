import Foundation

struct FuelPriceHistoryPoint: Identifiable, Codable {
    let price: Double?
    let rupture: Bool
    let timestamp: Int

    var id: Int { timestamp }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
