//
//  ReportIssueAPI.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 22/03/2026.
//


import Foundation
import UIKit

struct ReportIssueAttachment {
    let fileName: String
    let mimeType: String
    let data: Data
}

enum ReportIssueAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL API invalide."
        case .invalidResponse:
            return "Réponse serveur invalide."
        case .serverError(let message):
            return message
        }
    }
}

final class ReportIssueAPI {
    static let shared = ReportIssueAPI()

    private let baseURL = "https://api.carbunow.yannctr.fr"

    private init() {}

    func sendIssue(
        station: FuelStation,
        issueType: StationIssueType,
        message: String,
        contactEmail: String,
        attachment: ReportIssueAttachment?
    ) async throws {
        guard let url = URL(string: "\(baseURL)/reports/issues") else {
            throw ReportIssueAPIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "inconnue"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "inconnu"
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model

        let fields: [String: String] = [
            "station_id": station.id,
            "station_name": station.displayName,
            "station_subtitle": station.subtitle,
            "latitude": String(station.latitude),
            "longitude": String(station.longitude),
            "issue_type": issueType.rawValue,
            "issue_type_label": issueType.title,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "contact_email": contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            "app_version": appVersion,
            "build_number": buildNumber,
            "ios_version": systemVersion,
            "device_model": model
        ]

        request.httpBody = createMultipartBody(
            boundary: boundary,
            fields: fields,
            attachment: attachment
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ReportIssueAPIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ReportIssueAPIError.serverError("Erreur \(http.statusCode) : \(body)")
        }
    }

    private func createMultipartBody(
        boundary: String,
        fields: [String: String],
        attachment: ReportIssueAttachment?
    ) -> Data {
        var body = Data()

        for (key, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        if let attachment {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"attachment\"; filename=\"\(attachment.fileName)\"\r\n")
            body.appendString("Content-Type: \(attachment.mimeType)\r\n\r\n")
            body.append(attachment.data)
            body.appendString("\r\n")
        }

        body.appendString("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
