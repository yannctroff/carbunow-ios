//
//  SharedDefaults.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation

enum SharedDefaults {
    static let appGroupID = "group.com.cattarin.workhoursapp"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static let defaultFuelKey = "defaultFuel"
    static let searchRadiusKey = "searchRadiusKm"
    static let lastKnownLatitudeKey = "lastKnownLatitude"
    static let lastKnownLongitudeKey = "lastKnownLongitude"
    static let lastKnownLocationDateKey = "lastKnownLocationDate"
    static let activeAlertsKey = "active_price_alerts"
}
