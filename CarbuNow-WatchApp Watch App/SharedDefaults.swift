import Foundation

enum SharedDefaults {
    static let appGroupID = "group.com.cattarin.CarbuNow"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static let defaultFuelKey = "defaultFuel"
}