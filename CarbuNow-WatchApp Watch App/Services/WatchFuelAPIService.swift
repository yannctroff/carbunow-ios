//
//  WatchFuelAPIService.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation
import CoreLocation

final class WatchFuelAPIService {
    static let shared = WatchFuelAPIService()

    private let baseURL = "https://api.carbunow.yannctr.fr"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func fetchStations(
        around coordinate: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int = 100
    ) async throws -> [FuelStation] {
        let radiusMeters = max(radiusKm, 1) * 1000

        let earthRadius = 6_371_000.0
        let latDelta = (radiusMeters / earthRadius) * (180 / .pi)
        let lonDenominator = max(cos(coordinate.latitude * .pi / 180), 0.01)
        let lonDelta = (radiusMeters / (earthRadius * lonDenominator)) * (180 / .pi)

        let minLat = coordinate.latitude - latDelta
        let maxLat = coordinate.latitude + latDelta
        let minLon = coordinate.longitude - lonDelta
        let maxLon = coordinate.longitude + lonDelta

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
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "WatchFuelAPIService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Erreur API \(httpResponse.statusCode) : \(body)"]
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode([FuelStation].self, from: data)
    }
}
