//
//  AlertRegistrationRequest.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 19/03/2026.
//


import Foundation

struct AlertRegistrationRequest: Codable {
    let deviceToken: String
}

struct AlertUpsertRequest: Codable {
    let deviceToken: String
    let stationID: String
    let fuelType: String
    let isEnabled: Bool
}

final class AlertsAPI {
    static let shared = AlertsAPI()

    private let baseURL = URL(string: "https://api.carbunow.yannctr.fr")!

    private init() {}

    func registerDeviceToken(_ token: String) async throws {
        let url = baseURL.appendingPathComponent("alerts/register-device")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AlertRegistrationRequest(deviceToken: token))

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    func upsertPriceAlert(deviceToken: String, stationID: String, fuelType: String, isEnabled: Bool) async throws {
        let url = baseURL.appendingPathComponent("alerts/upsert")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AlertUpsertRequest(
                deviceToken: deviceToken,
                stationID: stationID,
                fuelType: fuelType,
                isEnabled: isEnabled
            )
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}