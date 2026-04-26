import WidgetKit
import SwiftUI
import CoreLocation

struct NearestStationEntry: TimelineEntry {
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

struct NearestStationProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearestStationEntry {
        NearestStationEntry(
            date: .now,
            stationID: "67890",
            latitude: 44.55,
            longitude: -0.24,
            stationName: "Intermarche Langon",
            priceText: "2.009 €/L",
            detailText: "Station la plus proche de toi.",
            fuelType: .gazole,
            statusText: "1.2 km",
            priceTrend: .up
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NearestStationEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearestStationEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func loadEntry() async -> NearestStationEntry {
        let defaults = WidgetSharedDefaults.shared
        let latitude = defaults.object(forKey: WidgetSharedDefaults.lastKnownLatitudeKey) as? Double
        let longitude = defaults.object(forKey: WidgetSharedDefaults.lastKnownLongitudeKey) as? Double
        let selectedFuel = WidgetFuelType(rawValue: defaults.string(forKey: WidgetSharedDefaults.defaultFuelKey) ?? WidgetFuelType.gazole.rawValue) ?? .gazole
        let radius = defaults.double(forKey: WidgetSharedDefaults.searchRadiusKey)

        guard let latitude, let longitude else {
            return NearestStationEntry(
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

            let nearest = stations.min { lhs, rhs in
                let lhsDistance = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: origin)
                let rhsDistance = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: origin)
                return lhsDistance < rhsDistance
            }

            guard let nearest else {
                return NearestStationEntry(
                    date: .now,
                    stationID: nil,
                    latitude: nil,
                    longitude: nil,
                    stationName: nil,
                    priceText: "Aucune station",
                    detailText: "Aucune station n’a ete trouvee dans ce rayon.",
                    fuelType: nil,
                    statusText: "Recherche",
                    priceTrend: nil
                )
            }

            let distance = CLLocation(latitude: nearest.latitude, longitude: nearest.longitude).distance(from: origin)
            let price = nearest.price(for: selectedFuel)
            let history = price == nil ? nil : (try? await WidgetAPI.fetchHistory(stationID: nearest.id, fuelType: selectedFuel))
            let trend = history.flatMap(widgetPriceTrend)

            return NearestStationEntry(
                date: .now,
                stationID: nearest.id,
                latitude: nearest.latitude,
                longitude: nearest.longitude,
                stationName: nearest.displayName,
                priceText: price.map { String(format: "%.3f €/L", $0) } ?? "Prix indisponible",
                detailText: price == nil ? "Station la plus proche sans prix pour ce carburant." : "Station la plus proche autour de toi.",
                fuelType: price == nil ? nil : selectedFuel,
                statusText: formattedDistance(distance),
                priceTrend: trend
            )
        } catch {
            return NearestStationEntry(
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

struct NearestStationWidget: Widget {
    let kind = "NearestStationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearestStationProvider()) { entry in
            NearestStationWidgetView(entry: entry)
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("Station la plus proche")
        .description("Affiche la station la plus proche de ta derniere position connue.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension NearestStationEntry {
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

private struct NearestStationWidgetView: View {
    let entry: NearestStationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetShell(
            icon: "mappin.and.ellipse",
            eyebrow: "Station la plus proche"
        ) {
            if let stationName = entry.stationName {
                content(stationName: stationName)
            } else {
                emptyState
            }
        }
    }

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

                if let statusText = entry.statusText {
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
            return entry.detailText
        }

        return "La station la plus proche de ta derniere position connue."
    }
}
