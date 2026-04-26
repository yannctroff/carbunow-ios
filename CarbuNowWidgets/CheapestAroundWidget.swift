import WidgetKit
import SwiftUI
import CoreLocation

struct CheapestAroundEntry: TimelineEntry {
    let date: Date
    let stationID: String?
    let latitude: Double?
    let longitude: Double?
    let stationName: String?
    let priceText: String
    let detailText: String
    let fuelType: WidgetFuelType?
    let statusText: String?
    let priceTrend: WidgetPriceTrend?
}

struct CheapestAroundProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheapestAroundEntry {
        CheapestAroundEntry(
            date: .now,
            stationID: "12345",
            latitude: 44.55,
            longitude: -0.24,
            stationName: "E.Leclerc Langon",
            priceText: "1.699 €/L",
            detailText: "4.2 km",
            fuelType: .gazole,
            statusText: nil,
            priceTrend: .down
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CheapestAroundEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheapestAroundEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func loadEntry() async -> CheapestAroundEntry {
        let defaults = WidgetSharedDefaults.shared
        let latitude = defaults.object(forKey: WidgetSharedDefaults.lastKnownLatitudeKey) as? Double
        let longitude = defaults.object(forKey: WidgetSharedDefaults.lastKnownLongitudeKey) as? Double
        let selectedFuel = WidgetFuelType(rawValue: defaults.string(forKey: WidgetSharedDefaults.defaultFuelKey) ?? WidgetFuelType.gazole.rawValue) ?? .gazole
        let radius = defaults.double(forKey: WidgetSharedDefaults.searchRadiusKey)

        guard let latitude, let longitude else {
            return CheapestAroundEntry(
                date: .now,
                stationID: nil,
                latitude: nil,
                longitude: nil,
                stationName: nil,
                priceText: "Ouvre l’app",
                detailText: "La position recente est necessaire pour ce widget.",
                fuelType: nil,
                statusText: "Position",
                priceTrend: nil
            )
        }

        do {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let stations = try await WidgetAPI.fetchStations(around: coordinate, radiusKm: radius == 0 ? 100 : radius)
            let origin = CLLocation(latitude: latitude, longitude: longitude)

            let cheapest = stations
                .filter { $0.price(for: selectedFuel) != nil }
                .min { lhs, rhs in
                    let lhsPrice = lhs.price(for: selectedFuel) ?? .greatestFiniteMagnitude
                    let rhsPrice = rhs.price(for: selectedFuel) ?? .greatestFiniteMagnitude

                    if lhsPrice == rhsPrice {
                        let lhsDistance = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: origin)
                        let rhsDistance = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: origin)
                        return lhsDistance < rhsDistance
                    }

                    return lhsPrice < rhsPrice
                }

            guard let cheapest, let price = cheapest.price(for: selectedFuel) else {
                return CheapestAroundEntry(
                    date: .now,
                    stationID: nil,
                    latitude: nil,
                    longitude: nil,
                    stationName: nil,
                    priceText: "Aucun prix",
                    detailText: "Aucune station n’a ete trouvee dans ce rayon.",
                    fuelType: nil,
                    statusText: nil,
                    priceTrend: nil
                )
                    .with(statusText: "Recherche")
            }

            let distance = CLLocation(latitude: cheapest.latitude, longitude: cheapest.longitude).distance(from: origin)
            let history = try? await WidgetAPI.fetchHistory(stationID: cheapest.id, fuelType: selectedFuel)
            let trend = history.flatMap(widgetPriceTrend)

            return CheapestAroundEntry(
                date: .now,
                stationID: cheapest.id,
                latitude: cheapest.latitude,
                longitude: cheapest.longitude,
                stationName: cheapest.displayName,
                priceText: String(format: "%.3f €/L", price),
                detailText: formattedDistance(distance),
                fuelType: selectedFuel,
                statusText: radius == 0 ? "Zone illimitee" : "\(Int(radius)) km",
                priceTrend: trend
            )
        } catch {
            return CheapestAroundEntry(
                date: .now,
                stationID: nil,
                latitude: nil,
                longitude: nil,
                stationName: nil,
                priceText: "Indisponible",
                detailText: "Le widget n’a pas pu charger les stations.",
                fuelType: nil,
                statusText: "Erreur",
                priceTrend: nil
            )
        }
    }

    private func formattedDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        }

        return String(format: "%.1f km", distance / 1000)
    }
}

struct CheapestAroundWidget: Widget {
    let kind = "CheapestAroundWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheapestAroundProvider()) { entry in
            CheapestAroundWidgetView(entry: entry)
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("Meilleur prix autour de moi")
        .description("Affiche la station la moins chere autour de ta derniere position connue.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension CheapestAroundEntry {
    func with(statusText: String?) -> CheapestAroundEntry {
        CheapestAroundEntry(
            date: date,
            stationID: stationID,
            latitude: latitude,
            longitude: longitude,
            stationName: stationName,
            priceText: priceText,
            detailText: detailText,
            fuelType: fuelType,
            statusText: statusText,
            priceTrend: priceTrend
        )
    }
}

private extension CheapestAroundEntry {
    var deepLinkURL: URL? {
        guard let stationID else { return nil }

        var components = URLComponents()
        components.scheme = "carbunow"
        components.host = "station"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "id", value: stationID)
        ]

        if let latitude {
            queryItems.append(URLQueryItem(name: "lat", value: String(latitude)))
        }

        if let longitude {
            queryItems.append(URLQueryItem(name: "lon", value: String(longitude)))
        }

        components.queryItems = queryItems

        return components.url
    }
}

private struct CheapestAroundWidgetView: View {
    let entry: CheapestAroundEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetShell(
            icon: "location.fill",
            eyebrow: "Meilleur prix autour"
        ) {
            if let stationName = entry.stationName {
                content(stationName: stationName)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func content(stationName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stationName)
                .font(.system(size: family == .systemSmall ? 15 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 4) {
                WidgetPriceLine(
                    priceText: entry.priceText,
                    trend: entry.priceTrend,
                    size: family == .systemSmall ? 29 : 31
                )

                Text(subtitleText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let fuelType = entry.fuelType {
                    WidgetMetricPill(text: fuelType.displayName)
                }

                WidgetMetricPill(text: entry.detailText)

                if family != .systemSmall, let statusText = entry.statusText {
                    WidgetMetricPill(text: statusText)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.priceText)
                .font(.system(size: family == .systemSmall ? 22 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(entry.detailText)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(family == .systemSmall ? 3 : 2)

            if let statusText = entry.statusText {
                WidgetMetricPill(text: statusText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var subtitleText: String {
        if family == .systemSmall {
            return "Selon ton carburant et ton rayon."
        }

        return "Station la moins chere autour de ta derniere position connue."
    }
}
