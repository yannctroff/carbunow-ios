import Foundation
import WidgetKit
import SwiftUI
import CoreLocation

enum WidgetSharedDefaults {
    static let appGroupID = "group.com.cattarin.workhoursapp"
    static let defaultFuelKey = "defaultFuel"
    static let searchRadiusKey = "searchRadiusKm"
    static let lastKnownLatitudeKey = "lastKnownLatitude"
    static let lastKnownLongitudeKey = "lastKnownLongitude"
    static let activeAlertsKey = "active_price_alerts"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

enum WidgetFuelType: String, CaseIterable, Codable {
    case gazole
    case sp95
    case sp98
    case e10
    case e85
    case gplc

    var displayName: String {
        switch self {
        case .gazole: return "Gazole"
        case .sp95: return "SP95"
        case .sp98: return "SP98"
        case .e10: return "E10"
        case .e85: return "E85"
        case .gplc: return "GPLc"
        }
    }

    var accent: Color {
        switch self {
        case .gazole: return Color(red: 0.24, green: 0.78, blue: 0.56)
        case .sp95: return Color(red: 0.98, green: 0.67, blue: 0.18)
        case .sp98: return Color(red: 0.96, green: 0.42, blue: 0.31)
        case .e10: return Color(red: 0.20, green: 0.67, blue: 0.96)
        case .e85: return Color(red: 0.53, green: 0.48, blue: 0.98)
        case .gplc: return Color(red: 0.48, green: 0.85, blue: 0.82)
        }
    }

    static func fromAPIValue(_ value: String) -> WidgetFuelType? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "gazole", "diesel":
            return .gazole
        case "sp95":
            return .sp95
        case "sp98":
            return .sp98
        case "e10", "sp95-e10":
            return .e10
        case "e85":
            return .e85
        case "gplc", "gpl":
            return .gplc
        default:
            return nil
        }
    }
}

struct WidgetFuelPrice: Decodable {
    let type: WidgetFuelType
    let price: Double

    enum CodingKeys: String, CodingKey {
        case fuel
        case price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawFuel = try container.decode(String.self, forKey: .fuel)

        guard let type = WidgetFuelType.fromAPIValue(rawFuel) else {
            throw DecodingError.dataCorruptedError(
                forKey: .fuel,
                in: container,
                debugDescription: "Carburant inconnu : \(rawFuel)"
            )
        }

        self.type = type
        self.price = try container.decode(Double.self, forKey: .price)
    }
}

struct WidgetPriceHistoryPoint: Decodable {
    let price: Double?
    let rupture: Bool
    let timestamp: Int
}

struct WidgetStation: Decodable, Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let cp: String?
    let city: String?
    let address: String?
    let name: String?
    let brand: String?
    let prices: [WidgetFuelPrice]

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

        return cityPart.isEmpty ? "Station \(id)" : cityPart
    }

    var compactName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        if let brand, !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return brand
        }

        return "Station \(id)"
    }

    func price(for fuel: WidgetFuelType) -> Double? {
        prices.first(where: { $0.type == fuel })?.price
    }
}

struct WidgetActiveAlert: Codable, Identifiable {
    let stationID: String
    let fuelType: String
    let isEnabled: Bool
    let stationName: String?

    var id: String {
        "\(stationID)|\(fuelType.lowercased())"
    }
}

enum WidgetAPI {
    private static let baseURL = "https://api.carbunow.yannctr.fr"

    static func fetchStations(around coordinate: CLLocationCoordinate2D, radiusKm: Double, limit: Int = 100) async throws -> [WidgetStation] {
        let radiusMeters = max(radiusKm, 1) * 1000
        let earthRadius = 6_371_000.0
        let latDelta = (radiusMeters / earthRadius) * (180 / .pi)
        let lonDelta = (radiusMeters / (earthRadius * cos(coordinate.latitude * .pi / 180))) * (180 / .pi)

        guard var components = URLComponents(string: "\(baseURL)/stations") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "min_lat", value: String(coordinate.latitude - latDelta)),
            URLQueryItem(name: "max_lat", value: String(coordinate.latitude + latDelta)),
            URLQueryItem(name: "min_lon", value: String(coordinate.longitude - lonDelta)),
            URLQueryItem(name: "max_lon", value: String(coordinate.longitude + lonDelta)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([WidgetStation].self, from: data)
    }

    static func fetchHistory(stationID: String, fuelType: WidgetFuelType, days: Int = 30) async throws -> [WidgetPriceHistoryPoint] {
        guard var components = URLComponents(string: "\(baseURL)/stations/\(stationID)/history") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "fuel_type", value: fuelType.rawValue),
            URLQueryItem(name: "days", value: String(days))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([WidgetPriceHistoryPoint].self, from: data)
    }
}

enum WidgetPriceTrend {
    case up
    case down
    case stable

    var symbolName: String {
        switch self {
        case .up:
            return "arrowtriangle.up.fill"
        case .down:
            return "arrowtriangle.down.fill"
        case .stable:
            return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up:
            return .red.opacity(0.9)
        case .down:
            return .green.opacity(0.9)
        case .stable:
            return .white.opacity(0.45)
        }
    }
}

func widgetPriceTrend(from history: [WidgetPriceHistoryPoint]) -> WidgetPriceTrend? {
    let priced = history
        .filter { $0.price != nil }
        .sorted { $0.timestamp < $1.timestamp }

    guard priced.count >= 2,
          let previous = priced.dropLast().last?.price,
          let latest = priced.last?.price else {
        return nil
    }

    if latest > previous {
        return .up
    }

    if latest < previous {
        return .down
    }

    return .stable
}

struct WidgetShell<Content: View>: View {
    let icon: String
    let eyebrow: String
    private let content: Content

    init(icon: String, eyebrow: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.eyebrow = eyebrow
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.10, green: 0.10, blue: 0.11)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.32))

                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(red: 0.10, green: 0.10, blue: 0.11)
        }
    }
}

struct WidgetMetricPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

struct WidgetPriceLine: View {
    let priceText: String
    let trend: WidgetPriceTrend?
    let size: CGFloat

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(priceText)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            if let trend {
                Image(systemName: trend.symbolName)
                    .font(.system(size: max(12, size * 0.42), weight: .bold))
                    .foregroundStyle(trend.color)
                    .offset(y: -2)
            }
        }
    }
}

extension WidgetFamily {
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }

    var isSystemSmall: Bool {
        #if os(watchOS)
        return false
        #else
        return self == .systemSmall
        #endif
    }
}
