import Foundation

enum StationIssueType: String, CaseIterable, Identifiable {
    case badLocation = "bad_location"
    case noAlert = "no_alert"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .badLocation:
            return "La station n’est pas bien placée sur la carte"
        case .noAlert:
            return "Je ne reçois pas d’alerte"
        case .other:
            return "Autre"
        }
    }
}