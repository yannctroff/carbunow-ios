import Foundation

struct FuelPrice: Decodable, Hashable {
    let type: FuelType
    let price: Double
    let updatedAtRaw: String?

    enum CodingKeys: String, CodingKey {
        case fuel
        case price
        case updatedAtRaw = "updated_at"
    }

    init(type: FuelType, price: Double, updatedAtRaw: String? = nil) {
        self.type = type
        self.price = price
        self.updatedAtRaw = updatedAtRaw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawFuel = try container.decode(String.self, forKey: .fuel)
        guard let fuelType = FuelType.fromAPIValue(rawFuel) else {
            throw DecodingError.dataCorruptedError(
                forKey: .fuel,
                in: container,
                debugDescription: "Carburant inconnu : \(rawFuel)"
            )
        }

        self.type = fuelType
        self.price = try container.decode(Double.self, forKey: .price)
        self.updatedAtRaw = try container.decodeIfPresent(String.self, forKey: .updatedAtRaw)
    }

    var updatedAt: Date? {
        guard let updatedAtRaw else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter.date(from: updatedAtRaw)
    }
}
