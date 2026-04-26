import WidgetKit
import SwiftUI

struct ActiveAlertsEntry: TimelineEntry {
    let date: Date
    let stationName: String?
    let fuelName: String?
    let fuelType: WidgetFuelType?
    let countText: String
    let detailText: String
}

struct ActiveAlertsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveAlertsEntry {
        ActiveAlertsEntry(
            date: .now,
            stationName: "E.Leclerc Langon",
            fuelName: "Gazole",
            fuelType: .gazole,
            countText: "2 alertes actives",
            detailText: "Seuil surveille sur tes alertes"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveAlertsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveAlertsEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> ActiveAlertsEntry {
        let defaults = WidgetSharedDefaults.shared

        guard let data = defaults.data(forKey: WidgetSharedDefaults.activeAlertsKey),
              let alerts = try? JSONDecoder().decode([WidgetActiveAlert].self, from: data) else {
            return ActiveAlertsEntry(
                date: .now,
                stationName: nil,
                fuelName: nil,
                fuelType: nil,
                countText: "0 alerte",
                detailText: "Active une alerte dans l’app pour la retrouver ici."
            )
        }

        let enabledAlerts = alerts.filter(\.isEnabled)

        guard let first = enabledAlerts.first else {
            return ActiveAlertsEntry(
                date: .now,
                stationName: nil,
                fuelName: nil,
                fuelType: nil,
                countText: "0 alerte",
                detailText: "Active une alerte dans l’app pour la retrouver ici."
            )
        }

        let fuelType = WidgetFuelType.fromAPIValue(first.fuelType)
        let fuel = fuelType?.displayName ?? first.fuelType.uppercased()
        let stationName = first.stationName ?? "Station \(first.stationID)"
        let countText = enabledAlerts.count > 1 ? "\(enabledAlerts.count) alertes actives" : "1 alerte active"
        let detailText = enabledAlerts.count > 1 ? "La premiere station surveillee" : "Alerte active en cours"

        return ActiveAlertsEntry(
            date: .now,
            stationName: stationName,
            fuelName: fuel,
            fuelType: fuelType,
            countText: countText,
            detailText: detailText
        )
    }
}

struct ActiveAlertsWidget: Widget {
    let kind = "ActiveAlertsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveAlertsProvider()) { entry in
            ActiveAlertsWidgetView(entry: entry)
                .widgetURL(URL(string: "carbunow://alerts"))
        }
        .configurationDisplayName("Alertes actives")
        .description("Affiche la station et le carburant de ta premiere alerte active.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct ActiveAlertsWidgetView: View {
    let entry: ActiveAlertsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetShell(
            icon: "bell.badge.fill",
            eyebrow: "Alertes actives"
        ) {
            if let stationName = entry.stationName {
                filledState(stationName: stationName)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func filledState(stationName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stationName)
                .font(.system(size: family == .systemSmall ? 15 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(compactCountText)
                    .font(.system(size: family == .systemSmall ? 30 : 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(compactCountLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(subtitleText)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(2)

            HStack(spacing: 8) {
                if let fuelName = entry.fuelName {
                    WidgetMetricPill(text: fuelName)
                }

                if family != .systemSmall {
                    WidgetMetricPill(text: entry.countText)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aucune alerte")
                .font(.system(size: family == .systemSmall ? 22 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(entry.detailText)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(family == .systemSmall ? 3 : 2)

            WidgetMetricPill(text: "Active des alertes")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactCountText: String {
        String(entry.countText.prefix { $0.isNumber })
    }

    private var compactCountLabel: String {
        compactCountText == "1" ? "alerte" : "alertes"
    }

    private var subtitleText: String {
        if family == .systemSmall {
            return entry.detailText
        }

        return "Retrouve rapidement la premiere station avec une alerte active."
    }
}
