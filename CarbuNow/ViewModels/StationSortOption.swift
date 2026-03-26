import Foundation

enum StationSortOption: String, CaseIterable, Hashable {
    case price
    case distance

    var label: String {
        switch self {
        case .price:
            return "Prix"
        case .distance:
            return "Distance"
        }
    }
}
