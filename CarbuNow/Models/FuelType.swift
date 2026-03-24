import Foundation

enum FuelType: String, CaseIterable, Identifiable, Codable {
    case gazole = "gazole"
    case sp95 = "sp95"
    case sp98 = "sp98"
    case e10 = "e10"
    case e85 = "e85"
    case gplc = "gplc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gazole:
            return "Gazole"
        case .sp95:
            return "SP95"
        case .sp98:
            return "SP98"
        case .e10:
            return "E10"
        case .e85:
            return "E85"
        case .gplc:
            return "GPLc"
        }
    }

    static func fromAPIValue(_ value: String) -> FuelType? {
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
