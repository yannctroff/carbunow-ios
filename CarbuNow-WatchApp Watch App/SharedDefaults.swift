//
//  SharedDefaults.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation

enum SharedDefaults {
    static let appGroupID = "group.com.cattarin.CarbuNow"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static let defaultFuelKey = "defaultFuel"
}
