//
//  PreviewData.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 15/03/2026.
//


import Foundation

enum PreviewData {
    static let stations: [FuelStation] = [
        FuelStation(
            id: "1",
            name: "Intermarché",
            brand: "Intermarché",
            address: "12 Avenue du 8 Mai",
            city: "Langon",
            latitude: 44.5540,
            longitude: -0.2490,
            prices: [
                FuelPrice(type: .gazole, price: 1.659),
                FuelPrice(type: .e10, price: 1.749),
                FuelPrice(type: .sp98, price: 1.869),
                FuelPrice(type: .e85, price: 0.799)
            ],
            updatedAt: Date()
        ),
        FuelStation(
            id: "2",
            name: "Carrefour",
            brand: "Carrefour",
            address: "Route de Bazas",
            city: "Langon",
            latitude: 44.5480,
            longitude: -0.2415,
            prices: [
                FuelPrice(type: .gazole, price: 1.672),
                FuelPrice(type: .e10, price: 1.739),
                FuelPrice(type: .sp95, price: 1.789)
            ],
            updatedAt: Date()
        ),
        FuelStation(
            id: "3",
            name: "TotalEnergies",
            brand: "TotalEnergies",
            address: "A62 Aire de Service",
            city: "Langon",
            latitude: 44.5605,
            longitude: -0.2300,
            prices: [
                FuelPrice(type: .gazole, price: 1.689),
                FuelPrice(type: .sp98, price: 1.899),
                FuelPrice(type: .gplc, price: 0.999)
            ],
            updatedAt: Date()
        )
    ]
}