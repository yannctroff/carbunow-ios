import Foundation

enum StationSortOption: String, CaseIterable, Identifiable {
    case price = "Prix"
    case distance = "Distance"

    var id: String { rawValue }
}
