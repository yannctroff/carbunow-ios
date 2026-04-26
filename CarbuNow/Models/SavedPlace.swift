import Foundation
import CoreLocation

struct SavedPlace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
