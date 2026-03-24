import Foundation
import CoreLocation

struct FuelStation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let address: String
    let city: String
    let latitude: Double
    let longitude: Double
    let prices: [FuelPrice]
    let updatedAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func price(for fuelType: FuelType) -> Double? {
        prices.first(where: { $0.type == fuelType })?.price
    }

    func distance(from location: CLLocation?) -> Double? {
        guard let location else { return nil }
        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stationLocation)
    }
}