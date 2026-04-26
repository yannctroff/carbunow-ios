import Foundation
import Combine

@MainActor
final class PriceAlertManager: ObservableObject {

    static let shared = PriceAlertManager()

    struct ActiveAlert: Codable, Equatable, Identifiable {
        let stationID: String
        let fuelType: String
        let isEnabled: Bool
        let stationName: String?

        init(stationID: String, fuelType: String, isEnabled: Bool = true, stationName: String? = nil) {
            self.stationID = stationID
            self.fuelType = fuelType.lowercased()
            self.isEnabled = isEnabled
            self.stationName = stationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var id: String {
            "\(stationID)|\(fuelType.lowercased())"
        }
    }

    struct DeviceAlertsResponse: Codable {
        let ok: Bool
        let alerts: [ServerAlert]
    }

    struct ServerAlert: Codable {
        let stationID: String
        let fuelType: String
        let isEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case stationID = "station_id"
            case fuelType = "fuel_type"
            case isEnabled = "is_enabled"
        }
    }

    enum ActivationResult {
        case activated
        case alreadyActive
    }

    @Published private(set) var activeAlerts: [ActiveAlert] = []

    private let baseURL = "https://api.carbunow.yannctr.fr"
    private init() {
        loadStoredAlerts()
    }

    private var deviceToken: String? {
        get { UserDefaults.standard.string(forKey: "apns_token") }
        set { UserDefaults.standard.setValue(newValue, forKey: "apns_token") }
    }

    private func loadStoredAlerts() {
        let defaults = SharedDefaults.shared

        guard let data = defaults.data(forKey: SharedDefaults.activeAlertsKey) ?? UserDefaults.standard.data(forKey: SharedDefaults.activeAlertsKey) else {
            activeAlerts = []
            return
        }

        do {
            let alerts = try JSONDecoder().decode([ActiveAlert].self, from: data)
            activeAlerts = deduplicated(alerts)
        } catch {
            print("Impossible de relire les alertes actives :", error.localizedDescription)
            activeAlerts = []
        }
    }

    private func saveAlerts() {
        do {
            let data = try JSONEncoder().encode(activeAlerts)
            SharedDefaults.shared.set(data, forKey: SharedDefaults.activeAlertsKey)
            UserDefaults.standard.set(data, forKey: SharedDefaults.activeAlertsKey)
            WidgetSyncCoordinator.reloadWidgets()
        } catch {
            print("Impossible de sauvegarder les alertes actives :", error.localizedDescription)
        }
    }

    private func deduplicated(_ alerts: [ActiveAlert]) -> [ActiveAlert] {
        var resultByID: [String: ActiveAlert] = [:]

        for alert in alerts {
            if let existing = resultByID[alert.id] {
                let resolvedName = existing.stationName?.isEmpty == false ? existing.stationName : alert.stationName
                resultByID[alert.id] = ActiveAlert(
                    stationID: alert.stationID,
                    fuelType: alert.fuelType,
                    isEnabled: alert.isEnabled || existing.isEnabled,
                    stationName: resolvedName
                )
            } else {
                resultByID[alert.id] = alert
            }
        }

        return resultByID.values.sorted { $0.id < $1.id }
    }

    func isAlertActive(stationID: String, fuelType: String) -> Bool {
        let key = "\(stationID)|\(fuelType.lowercased())"
        return activeAlerts.contains { $0.id == key && $0.isEnabled }
    }

    func clearLocalAlertsCache() {
        activeAlerts = []
        UserDefaults.standard.removeObject(forKey: SharedDefaults.activeAlertsKey)
        SharedDefaults.shared.removeObject(forKey: SharedDefaults.activeAlertsKey)
        WidgetSyncCoordinator.reloadWidgets()
    }

    func registerDevice(token: String) async {
        self.deviceToken = token

        guard let url = URL(string: "\(baseURL)/alerts/register-device") else { return }

        let body: [String: Any] = [
            "deviceToken": token
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await URLSession.shared.data(for: request)
            try? await fetchAlertsFromServer()
        } catch {
            print("Impossible d’enregistrer le device token :", error.localizedDescription)
        }
    }

    func fetchAlertsFromServer() async throws {
        guard let token = deviceToken, !token.isEmpty else {
            activeAlerts = deduplicated(activeAlerts)
            saveAlerts()
            return
        }

        var components = URLComponents(string: "\(baseURL)/alerts/by-device")
        components?.queryItems = [
            URLQueryItem(name: "deviceToken", value: token)
        ]

        guard let url = components?.url else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "URL API invalide."]
            )
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Réponse serveur invalide."]
            )
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "PriceAlertManager",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de récupérer les alertes du serveur."]
            )
        }

        let decoded = try JSONDecoder().decode(DeviceAlertsResponse.self, from: data)
        let mapped = decoded.alerts
            .filter { $0.isEnabled }
            .map {
                let key = "\($0.stationID)|\($0.fuelType.lowercased())"
                let savedName = activeAlerts.first(where: { $0.id == key })?.stationName
                return ActiveAlert(
                    stationID: $0.stationID,
                    fuelType: $0.fuelType,
                    isEnabled: $0.isEnabled,
                    stationName: savedName
                )
            }

        activeAlerts = deduplicated(mapped)
        saveAlerts()
    }

    func activateAlert(stationID: String, fuelType: String, stationName: String? = nil) async throws -> ActivationResult {
        guard let token = deviceToken, !token.isEmpty else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Les notifications push ne sont pas encore prêtes sur cet appareil."]
            )
        }

        let normalizedFuelType = fuelType.lowercased()

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

        let alreadyActiveBeforeRefresh = isAlertActive(
            stationID: stationID,
            fuelType: normalizedFuelType
        )

        try? await fetchAlertsFromServer()
        rememberStationName(stationName, forStationID: stationID, fuelType: normalizedFuelType)

        return alreadyActiveBeforeRefresh ? .alreadyActive : .activated
    }

    func rememberStationName(_ stationName: String?, forStationID stationID: String, fuelType: String) {
        guard let stationName, !stationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let normalizedFuelType = fuelType.lowercased()
        let alertID = "\(stationID)|\(normalizedFuelType)"

        guard let index = activeAlerts.firstIndex(where: { $0.id == alertID }) else { return }

        if activeAlerts[index].stationName == stationName {
            return
        }

        activeAlerts[index] = ActiveAlert(
            stationID: activeAlerts[index].stationID,
            fuelType: activeAlerts[index].fuelType,
            isEnabled: activeAlerts[index].isEnabled,
            stationName: stationName
        )
        saveAlerts()
    }

    func refreshStationNames(using stations: [FuelStation]) {
        var didChange = false
        var updatedAlerts = activeAlerts

        for index in updatedAlerts.indices {
            if let station = stations.first(where: { $0.id == updatedAlerts[index].stationID }),
               updatedAlerts[index].stationName != station.displayName {
                updatedAlerts[index] = ActiveAlert(
                    stationID: updatedAlerts[index].stationID,
                    fuelType: updatedAlerts[index].fuelType,
                    isEnabled: updatedAlerts[index].isEnabled,
                    stationName: station.displayName
                )
                didChange = true
            }
        }

        guard didChange else { return }
        activeAlerts = deduplicated(updatedAlerts)
        saveAlerts()
    }

    func removeAlert(stationID: String, fuelType: String) async throws {
        guard let token = deviceToken, !token.isEmpty else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Les notifications push ne sont pas encore prêtes sur cet appareil."]
            )
        }

        guard let url = URL(string: "\(baseURL)/alerts/upsert") else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "URL API invalide."]
            )
        }

        let normalizedFuelType = fuelType.lowercased()

        let body: [String: Any] = [
            "deviceToken": token,
            "stationID": stationID,
            "fuelType": normalizedFuelType,
            "isEnabled": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "PriceAlertManager",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de supprimer l’alerte."]
            )
        }

        try? await fetchAlertsFromServer()
    }

    func setAllAlertsEnabled(_ isEnabled: Bool) async {
        guard let token = deviceToken, !token.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/alerts/set-enabled-for-device") else { return }

        let body: [String: Any] = [
            "deviceToken": token,
            "isEnabled": isEnabled
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("Impossible de mettre à jour l’état global des alertes")
                return
            }
            try? await fetchAlertsFromServer()
        } catch {
            print("Erreur mise à jour état global des alertes :", error.localizedDescription)
        }
    }

    func replaceAllAlerts(_ alerts: [ActiveAlert]) {
        activeAlerts = deduplicated(alerts)
        saveAlerts()
    }
}
