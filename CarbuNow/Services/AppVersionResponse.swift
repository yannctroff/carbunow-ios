import Foundation

struct AppVersionResponse: Decodable {
    let version: String?
    let force_update: Bool
}

@MainActor
final class VersionChecker: ObservableObject {
    @Published var showUpdateAlert = false
    @Published var latestVersion: String?

    func check() async {
        guard let url = URL(string: "https://api.carbunow.yannctr.fr/app-version") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            let decoded = try JSONDecoder().decode(AppVersionResponse.self, from: data)

            guard let storeVersion = decoded.version else { return }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

            if isNewer(storeVersion, than: currentVersion) {
                latestVersion = storeVersion
                showUpdateAlert = true
            }

        } catch {
            print("Version check error:", error)
        }
    }

    private func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let l = lhs.split(separator: ".").compactMap { Int($0) }
        let r = rhs.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(l.count, r.count) {
            let lv = i < l.count ? l[i] : 0
            let rv = i < r.count ? r[i] : 0

            if lv > rv { return true }
            if lv < rv { return false }
        }
        return false
    }
}