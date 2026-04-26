import Foundation
import CoreLocation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSyncCoordinator {
    static func storeLatestLocation(_ location: CLLocation) {
        let defaults = SharedDefaults.shared
        let previousLatitude = defaults.object(forKey: SharedDefaults.lastKnownLatitudeKey) as? Double
        let previousLongitude = defaults.object(forKey: SharedDefaults.lastKnownLongitudeKey) as? Double
        let previousTimestamp = defaults.object(forKey: SharedDefaults.lastKnownLocationDateKey) as? TimeInterval

        defaults.set(location.coordinate.latitude, forKey: SharedDefaults.lastKnownLatitudeKey)
        defaults.set(location.coordinate.longitude, forKey: SharedDefaults.lastKnownLongitudeKey)
        defaults.set(location.timestamp.timeIntervalSince1970, forKey: SharedDefaults.lastKnownLocationDateKey)

        let shouldReload: Bool

        if let previousLatitude, let previousLongitude, let previousTimestamp {
            let previousLocation = CLLocation(latitude: previousLatitude, longitude: previousLongitude)
            let movedDistance = previousLocation.distance(from: location)
            let elapsed = location.timestamp.timeIntervalSince1970 - previousTimestamp
            shouldReload = movedDistance >= 1_000 || elapsed >= 900
        } else {
            shouldReload = true
        }

        if shouldReload {
            reloadWidgets()
        }
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
