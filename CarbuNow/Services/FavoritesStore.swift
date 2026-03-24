//
//  FavoritesStore.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import Foundation
import Combine

final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String> = []

    private let key = "favorite_station_ids"

    init() {
        load()
    }

    func isFavorite(_ station: FuelStation) -> Bool {
        favoriteIDs.contains(station.id)
    }

    func toggle(_ station: FuelStation) {
        if favoriteIDs.contains(station.id) {
            favoriteIDs.remove(station.id)
        } else {
            favoriteIDs.insert(station.id)
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: key)
    }

    private func load() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        favoriteIDs = Set(saved)
    }
}
