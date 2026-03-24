import Foundation

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case gazole
    case sp95
    case sp98
    case e10
    case e85
    case gplc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gazole: return "Gazole"
        case .sp95: return "SP95"
        case .sp98: return "SP98"
        case .e10: return "E10"
        case .e85: return "E85"
        case .gplc: return "GPLc"
        }
    }
}