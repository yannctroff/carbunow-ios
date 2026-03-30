import Foundation

struct FuelPriceHistoryPoint: Codable, Identifiable {
    let id = UUID()
    let price: Double?
    let rupture: Bool
    let timestamp: Int

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}