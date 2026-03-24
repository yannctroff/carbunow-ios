import Foundation

struct FuelPrice: Codable, Hashable {
    let type: FuelType
    let price: Double
}