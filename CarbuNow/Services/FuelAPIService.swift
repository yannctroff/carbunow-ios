import Foundation
import CoreLocation
import MapKit

final class FuelAPIService {
    private let baseURL = "https://api.carbunow.yannctr.fr"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func fetchStations(in region: MKCoordinateRegion, limit: Int = 200) async throws -> [FuelStation] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return try await fetchStations(
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            limit: limit
        )
    }

    func fetchStations(around coordinate: CLLocationCoordinate2D, radiusKm: Double, limit: Int = 300) async throws -> [FuelStation] {
        let radiusMeters = max(radiusKm, 1) * 1000

        let earthRadius = 6_371_000.0
        let latDelta = (radiusMeters / earthRadius) * (180 / .pi)
        let lonDelta = (radiusMeters / (earthRadius * cos(coordinate.latitude * .pi / 180))) * (180 / .pi)

        let minLat = coordinate.latitude - latDelta
        let maxLat = coordinate.latitude + latDelta
        let minLon = coordinate.longitude - lonDelta
        let maxLon = coordinate.longitude + lonDelta

        return try await fetchStations(
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            limit: limit
        )
    }

    private func fetchStations(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        limit: Int
    ) async throws -> [FuelStation] {
        guard var components = URLComponents(string: "\(baseURL)/stations") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "min_lat", value: String(minLat)),
            URLQueryItem(name: "max_lat", value: String(maxLat)),
            URLQueryItem(name: "min_lon", value: String(minLon)),
            URLQueryItem(name: "max_lon", value: String(maxLon)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "FuelAPIService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Erreur API \(httpResponse.statusCode) : \(body)"]
            )
        }

        do {
            let decoder = JSONDecoder()
            let stations = try decoder.decode([FuelStation].self, from: data)
            return stations
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("❌ Décodage stations impossible : \(error)")
            print("📦 Réponse brute : \(raw)")
            throw error
        }
    }
}
