import Foundation
import CoreLocation
import SwiftUI

struct FuelStation: Decodable, Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let cp: String?
    let city: String?
    let address: String?
    let name: String?
    let brand: String?
    let prices: [FuelPrice]
    let ruptures: [FuelRupture]
    let updatedAtRaw: String?

    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case cp
        case city
        case address
        case name
        case brand
        case prices
        case ruptures
        case updatedAtRaw = "updated_at"
    }

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        cp: String? = nil,
        city: String? = nil,
        address: String? = nil,
        name: String? = nil,
        brand: String? = nil,
        prices: [FuelPrice],
        ruptures: [FuelRupture] = [],
        updatedAtRaw: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.cp = cp
        self.city = city
        self.address = address
        self.name = name
        self.brand = brand
        self.prices = prices
        self.ruptures = ruptures
        self.updatedAtRaw = updatedAtRaw
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

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

        if !cityPart.isEmpty {
            return cityPart
        }

        if let address, !address.isEmpty {
            return address
        }

        return "Station \(id)"
    }

    var subtitle: String {
        [cp, city, address]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    var normalizedBrand: StationBrand? {
        StationBrand.resolve(from: brand, name: name, displayName: displayName)
    }

    var updatedAt: Date? {
        guard let updatedAtRaw else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter.date(from: updatedAtRaw)
    }

    var updatedAtText: String? {
        guard let updatedAt else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Mise à jour le \(formatter.string(from: updatedAt))"
    }

    func price(for fuel: FuelType) -> Double? {
        prices.first(where: { $0.type == fuel })?.price
    }

    func hasActiveRupture(for fuel: FuelType) -> Bool {
        ruptures.contains(where: { $0.type == fuel && $0.isActive })
    }

    func hasActiveTemporaryRupture(for fuel: FuelType) -> Bool {
        ruptures.contains(where: {
            $0.type == fuel &&
            $0.isActive &&
            ($0.kind ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "temporaire"
        })
    }

    var hasAnyActiveRupture: Bool {
        ruptures.contains(where: { $0.isActive })
    }

    var hasAnyActiveTemporaryRupture: Bool {
        ruptures.contains(where: {
            $0.isActive &&
            ($0.kind ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "temporaire"
        })
    }

    func isAvailable(for fuel: FuelType) -> Bool {
        price(for: fuel) != nil || hasActiveRupture(for: fuel)
    }

    func shouldAppear(for fuel: FuelType) -> Bool {
        if isAvailable(for: fuel) {
            return true
        }

        return prices.isEmpty && hasAnyActiveTemporaryRupture
    }

    func shouldShowRuptureBadge(for fuel: FuelType) -> Bool {
        if hasActiveRupture(for: fuel) {
            return true
        }

        return prices.isEmpty && hasAnyActiveTemporaryRupture
    }

    var availableFuelTypes: [FuelType] {
        FuelType.allCases.filter { isAvailable(for: $0) }
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stationLocation)
    }
}

enum StationBrand: String, Hashable {
    case totalEnergies
    case totalAccess
    case esso
    case essoExpress
    case eLeclerc
    case intermarché
    case carrefour
    case carrefourMarket
    case superU
    case hyperU
    case auchan
    case casino
    case géantCasino
    case avia
    case bp
    case shell
    case dyneff
    case systèmeU
    case netto
    case cora
    case match
    case simplyMarket
    case agip
    case eni
    case elán

    var shortLabel: String {
        switch self {
        case .totalEnergies: return "TE"
        case .totalAccess: return "TA"
        case .esso: return "Esso"
        case .essoExpress: return "Esso"
        case .eLeclerc: return "E.L"
        case .intermarché: return "ITM"
        case .carrefour: return "C"
        case .carrefourMarket: return "CM"
        case .superU: return "U"
        case .hyperU: return "HU"
        case .auchan: return "A"
        case .casino: return "Casino"
        case .géantCasino: return "Géant"
        case .avia: return "Avia"
        case .bp: return "BP"
        case .shell: return "Shell"
        case .dyneff: return "Dyn"
        case .systèmeU: return "U"
        case .netto: return "Netto"
        case .cora: return "Cora"
        case .match: return "Match"
        case .simplyMarket: return "Simply"
        case .agip: return "Agip"
        case .eni: return "Eni"
        case .elán: return "Elan"
        }
    }

    var logoAssetName: String {
        switch self {
        case .totalEnergies, .totalAccess:
            return "logo_totalenergies"
        case .esso, .essoExpress:
            return "logo_esso"
        case .eLeclerc:
            return "logo_eleclerc"
        case .intermarché:
            return "logo_intermarche"
        case .carrefour, .carrefourMarket:
            return "logo_carrefour"
        case .superU, .hyperU, .systèmeU:
            return "logo_systeme_u"
        case .auchan:
            return "logo_auchan"
        case .casino, .géantCasino:
            return "logo_casino"
        case .avia:
            return "logo_avia"
        case .bp:
            return "logo_bp"
        case .shell:
            return "logo_shell"
        case .dyneff:
            return "logo_dyneff"
        case .netto:
            return "logo_netto"
        case .cora:
            return "logo_cora"
        case .match:
            return "logo_match"
        case .simplyMarket:
            return "logo_simply_market"
        case .agip, .eni:
            return "logo_eni"
        case .elán:
            return "logo_elan"
        }
    }

    var usesWideMapMarker: Bool {
        switch self {
        case .intermarché:
            return true
        default:
            return false
        }
    }

    var logoURL: URL? {
        switch self {
        case .totalEnergies, .totalAccess:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/d/d8/Logo_TotalEnergies.svg/320px-Logo_TotalEnergies.svg.png")
        case .esso, .essoExpress:
            return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/Esso_textlogo.svg/320px-Esso_textlogo.svg.png")
        case .eLeclerc:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/8/8b/E.Leclerc_logo.svg/320px-E.Leclerc_logo.svg.png")
        case .intermarché:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/0/0b/Intermarch%C3%A9_logo_2022.svg/320px-Intermarch%C3%A9_logo_2022.svg.png")
        case .carrefour, .carrefourMarket:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/3/3b/Logo_Carrefour.svg/320px-Logo_Carrefour.svg.png")
        case .superU, .hyperU, .systèmeU:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/5/5f/Logo_Syst%C3%A8me_U.svg/320px-Logo_Syst%C3%A8me_U.svg.png")
        case .auchan:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/2/29/Auchan_Retail_logo.svg/320px-Auchan_Retail_logo.svg.png")
        case .casino, .géantCasino:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/d/d3/Groupe_Casino_logo.svg/320px-Groupe_Casino_logo.svg.png")
        case .avia:
            return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Avia.svg/320px-Avia.svg.png")
        case .bp:
            return URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/BP_logo.svg/320px-BP_logo.svg.png")
        case .shell:
            return URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/e/e8/Shell_logo.svg/320px-Shell_logo.svg.png")
        case .dyneff:
            return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Dyneff_logo.svg/320px-Dyneff_logo.svg.png")
        case .netto:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/1/12/Netto_logo.svg/320px-Netto_logo.svg.png")
        case .cora:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/9/90/Cora_logo.svg/320px-Cora_logo.svg.png")
        case .match:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/7/7b/Supermarch%C3%A9s_Match_logo.svg/320px-Supermarch%C3%A9s_Match_logo.svg.png")
        case .simplyMarket:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/5/5f/Simply_Market_logo.svg/320px-Simply_Market_logo.svg.png")
        case .agip:
            return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Agip_logo.svg/320px-Agip_logo.svg.png")
        case .eni:
            return URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/e/e8/Eni_logo.svg/320px-Eni_logo.svg.png")
        case .elán:
            return URL(string: "https://upload.wikimedia.org/wikipedia/fr/thumb/2/28/Elan_logo.svg/320px-Elan_logo.svg.png")
        }
    }

    var markerTint: Color {
        switch self {
        case .totalEnergies, .totalAccess, .eLeclerc, .carrefour, .carrefourMarket, .superU, .hyperU, .systèmeU:
            return .blue
        case .esso, .essoExpress, .intermarché, .auchan, .avia, .cora, .match, .simplyMarket, .agip, .eni, .elán:
            return .red
        case .casino, .géantCasino, .bp:
            return .green
        case .shell, .netto:
            return .yellow
        case .dyneff:
            return .orange
        }
    }

    static func resolve(from brand: String?, name: String?, displayName: String) -> StationBrand? {
        let source = [brand, name, displayName]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if source.contains("total access") { return .totalAccess }
        if source.contains("totalenergies") || source.contains("total energies") || source.contains("total") { return .totalEnergies }
        if source.contains("esso express") { return .essoExpress }
        if source.contains("esso") { return .esso }
        if source.contains("leclerc") || source.contains("e.leclerc") || source.contains("e leclerc") { return .eLeclerc }
        if source.contains("intermarche") { return .intermarché }
        if source.contains("carrefour market") { return .carrefourMarket }
        if source.contains("carrefour") { return .carrefour }
        if source.contains("hyper u") { return .hyperU }
        if source.contains("super u") { return .superU }
        if source.contains("systeme u") || source.contains("system u") { return .systèmeU }
        if source.contains("auchan") { return .auchan }
        if source.contains("geant casino") { return .géantCasino }
        if source.contains("casino") { return .casino }
        if source.contains("avia") { return .avia }
        if source.contains("bp") { return .bp }
        if source.contains("shell") { return .shell }
        if source.contains("dyneff") { return .dyneff }
        if source.contains("netto") { return .netto }
        if source.contains("cora") { return .cora }
        if source.contains("match") { return .match }
        if source.contains("simply") { return .simplyMarket }
        if source.contains("agip") { return .agip }
        if source.contains("eni") { return .eni }
        if source.contains("elan") { return .elán }
        return nil
    }
}
