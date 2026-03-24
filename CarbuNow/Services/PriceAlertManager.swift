import Foundation
import UserNotifications

@MainActor
final class PriceAlertManager: ObservableObject {
    static let shared = PriceAlertManager()

    @Published var isEnabled: Bool
    @Published var selectedStationID: String
    @Published var selectedFuel: FuelType

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "priceAlert.isEnabled"
        static let selectedStationID = "priceAlert.selectedStationID"
        static let selectedFuel = "priceAlert.selectedFuel"
        static let lastKnownPrice = "priceAlert.lastKnownPrice"
        static let lastChangeSignature = "priceAlert.lastChangeSignature"
    }

    private init() {
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.selectedStationID = defaults.string(forKey: Keys.selectedStationID) ?? ""

        if let rawFuel = defaults.string(forKey: Keys.selectedFuel),
           let fuel = FuelType(rawValue: rawFuel) {
            self.selectedFuel = fuel
        } else {
            self.selectedFuel = .gazole
        }
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: Keys.isEnabled)
    }

    func setSelectedStationID(_ stationID: String) {
        selectedStationID = stationID
        defaults.set(stationID, forKey: Keys.selectedStationID)
    }

    func setSelectedFuel(_ fuel: FuelType) {
        selectedFuel = fuel
        defaults.set(fuel.rawValue, forKey: Keys.selectedFuel)
    }

    func requestAuthorization() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notifications autorisées :", granted)
        } catch {
            print("❌ Erreur autorisation notifications :", error.localizedDescription)
        }
    }

    func evaluatePriceChange(in stations: [FuelStation]) async {
        guard isEnabled else { return }
        guard !selectedStationID.isEmpty else { return }

        guard let station = stations.first(where: { $0.id == selectedStationID }) else { return }
        guard let currentPrice = station.price(for: selectedFuel) else { return }

        let previousPrice = defaults.object(forKey: Keys.lastKnownPrice) as? Double
        let currentSignature = changeSignature(for: station, price: currentPrice, fuel: selectedFuel)
        let lastSignature = defaults.string(forKey: Keys.lastChangeSignature)

        defaults.set(currentPrice, forKey: Keys.lastKnownPrice)

        guard let previousPrice else {
            print("🔔 Prix initial mémorisé :", currentPrice)
            return
        }

        guard abs(currentPrice - previousPrice) >= 0.0005 else {
            return
        }

        guard currentSignature != lastSignature else {
            return
        }

        await sendNotification(
            station: station,
            fuel: selectedFuel,
            newPrice: currentPrice,
            oldPrice: previousPrice
        )

        defaults.set(currentSignature, forKey: Keys.lastChangeSignature)
    }

    private func changeSignature(for station: FuelStation, price: Double, fuel: FuelType) -> String {
        let updatedPart: String
        if let updatedAt = station.updatedAt {
            updatedPart = String(updatedAt.timeIntervalSince1970)
        } else {
            updatedPart = "no-date"
        }

        return "\(station.id)|\(fuel.rawValue)|\(String(format: "%.3f", price))|\(updatedPart)"
    }

    private func sendNotification(
        station: FuelStation,
        fuel: FuelType,
        newPrice: Double,
        oldPrice: Double
    ) async {
        let delta = abs(newPrice - oldPrice)
        let isDown = newPrice < oldPrice

        let trendWord = isDown ? "baisse" : "hausse"
        let trendEmoji = isDown ? "📉" : "📈"

        let title = "Nouveau prix du \(fuel.displayName) dans votre station !"
        let body = "Le \(fuel.displayName) est à \(formatPrice(newPrice)) (€) (\(trendWord) de \(formatPrice(delta)) par rapport au prix précédent \(trendEmoji))"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "price-alert-\(station.id)-\(fuel.rawValue)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Notification envoyée pour \(station.id) - \(fuel.displayName)")
        } catch {
            print("❌ Impossible d'envoyer la notification :", error.localizedDescription)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)) + "€"
    }
}