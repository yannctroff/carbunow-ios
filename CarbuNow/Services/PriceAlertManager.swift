import Foundation
import Combine

@MainActor
final class PriceAlertManager: ObservableObject {

    static let shared = PriceAlertManager()

    struct ActiveAlert: Codable, Equatable {
        let stationID: String
        let fuelType: String
    }

    enum ActivationResult {
        case activated
        case replaced(previous: ActiveAlert)
        case alreadyActive
    }

    @Published private(set) var activeAlert: ActiveAlert?

    private let baseURL = "https://api.carbunow.yannctr.fr"
    private let activeAlertKey = "active_price_alert"
    private let settingsEnabledKey = "priceAlert.isEnabled"
    private let settingsStationIDKey = "priceAlert.selectedStationID"
    private let settingsFuelKey = "priceAlert.selectedFuel"

    private init() {
        loadStoredActiveAlert()
    }

    private var deviceToken: String? {
        get { UserDefaults.standard.string(forKey: "apns_token") }
        set { UserDefaults.standard.setValue(newValue, forKey: "apns_token") }
    }

    private func loadStoredActiveAlert() {
        guard let data = UserDefaults.standard.data(forKey: activeAlertKey) else {
            activeAlert = nil
            return
        }

        do {
            let alert = try JSONDecoder().decode(ActiveAlert.self, from: data)
            activeAlert = alert

            UserDefaults.standard.set(true, forKey: settingsEnabledKey)
            UserDefaults.standard.set(alert.stationID, forKey: settingsStationIDKey)
            UserDefaults.standard.set(alert.fuelType.lowercased(), forKey: settingsFuelKey)
        } catch {
            print("❌ Impossible de relire l’alerte active:", error.localizedDescription)
            activeAlert = nil
        }
    }   

    private func saveActiveAlert(_ alert: ActiveAlert?) {
        activeAlert = alert

        if let alert {
            do {
                let data = try JSONEncoder().encode(alert)
                UserDefaults.standard.set(data, forKey: activeAlertKey)
            } catch {
                print("❌ Impossible de sauvegarder l’alerte active:", error.localizedDescription)
            }

            UserDefaults.standard.set(true, forKey: settingsEnabledKey)
            UserDefaults.standard.set(alert.stationID, forKey: settingsStationIDKey)
            UserDefaults.standard.set(alert.fuelType.lowercased(), forKey: settingsFuelKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeAlertKey)

            UserDefaults.standard.set(false, forKey: settingsEnabledKey)
            UserDefaults.standard.removeObject(forKey: settingsStationIDKey)
            UserDefaults.standard.removeObject(forKey: settingsFuelKey)
        }
    }

    func isAlertActive(stationID: String, fuelType: String) -> Bool {
        activeAlert?.stationID == stationID &&
        activeAlert?.fuelType.lowercased() == fuelType.lowercased()
    }

    func registerDevice(token: String) {
        print("📡 registerDevice called with token:", token.prefix(20), "...")

        self.deviceToken = token

        guard let url = URL(string: "\(baseURL)/alerts/register-device") else { return }

        let body: [String: Any] = [
            "deviceToken": token
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ registerDevice error:", error)
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📡 registerDevice status:", http.statusCode)
            }

            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📡 registerDevice response:", body)
            }

            print("✅ Device enregistré")
        }.resume()
    }

    func activateAlert(stationID: String, fuelType: String) async throws -> ActivationResult {
        guard let token = deviceToken, !token.isEmpty else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Les notifications push ne sont pas encore prêtes sur cet appareil."]
            )
        }

        let normalizedFuelType = fuelType.lowercased()

        if isAlertActive(stationID: stationID, fuelType: normalizedFuelType) {
            return .alreadyActive
        }

        let previousAlert = activeAlert

        print("📡 activateAlert →", stationID, normalizedFuelType)

        guard let url = URL(string: "\(baseURL)/alerts/upsert") else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL API invalide."]
            )
        }

        let body: [String: Any] = [
            "deviceToken": token,
            "stationID": stationID,
            "fuelType": normalizedFuelType,
            "isEnabled": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Réponse serveur invalide."]
            )
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "PriceAlertManager",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Le serveur a refusé l’activation de l’alerte."]
            )
        }

        let newAlert = ActiveAlert(
            stationID: stationID,
            fuelType: normalizedFuelType
        )

        saveActiveAlert(newAlert)

        if let previousAlert {
            return .replaced(previous: previousAlert)
        } else {
            return .activated
        }
    }
}
