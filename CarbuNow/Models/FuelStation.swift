import Foundation
import CoreLocation
import MapKit

struct FuelStation: Decodable, Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let cp: String?
    let city: String?
    let address: String?
    let name: String?
    let prices: [FuelPrice]
    let ruptures: [FuelRupture]
    let updatedAtRaw: String?

    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case cp
        case city
        case address
        case name
        case prices
        case ruptures
        case updatedAtRaw = "updated_at"
    }

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        cp: String? = nil,
        city: String? = nil,
        address: String? = nil,
        name: String? = nil,
        prices: [FuelPrice],
        ruptures: [FuelRupture] = [],
        updatedAtRaw: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.cp = cp
        self.city = city
        self.address = address
        self.name = name
        self.prices = prices
        self.ruptures = ruptures
        self.updatedAtRaw = updatedAtRaw
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        let cityPart = [cp, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !cityPart.isEmpty, let address, !address.isEmpty {
            return "\(cityPart) • \(address)"
        }

        if !cityPart.isEmpty {
            return cityPart
        }

        if let address, !address.isEmpty {
            return address
        }

        return "Station \(id)"
    }

    var subtitle: String {
        [cp, city, address]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    var updatedAt: Date? {
        guard let updatedAtRaw else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter.date(from: updatedAtRaw)
    }

    var updatedAtText: String? {
        guard let updatedAt else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Mise à jour le \(formatter.string(from: updatedAt))"
    }

    func price(for fuel: FuelType) -> Double? {
        prices.first(where: { $0.type == fuel })?.price
    }

    func hasActiveRupture(for fuel: FuelType) -> Bool {
        ruptures.contains(where: { $0.type == fuel && $0.isActive })
    }

    func isAvailable(for fuel: FuelType) -> Bool {
        price(for: fuel) != nil || hasActiveRupture(for: fuel)
    }

    var availableFuelTypes: [FuelType] {
        FuelType.allCases.filter { isAvailable(for: $0) }
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stationLocation)
    }
}
