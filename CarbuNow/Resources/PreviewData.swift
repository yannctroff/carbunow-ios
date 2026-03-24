import Foundation

enum PreviewData {
    static let stations: [FuelStation] = [
        FuelStation(
            id: "33720009",
            latitude: 44.562,
            longitude: -0.419,
            cp: "33720",
            city: "Landiras",
            address: "99 ROUTE DE GUILLOS",
            prices: [
                FuelPrice(type: .gazole, price: 2.099, updatedAtRaw: "2026-03-19 11:37:11"),
                FuelPrice(type: .e10, price: 1.859, updatedAtRaw: "2026-03-19 11:37:12"),
                FuelPrice(type: .sp98, price: 1.949, updatedAtRaw: "2026-03-19 11:37:12")
            ],
            updatedAtRaw: "2026-03-19 11:37:12"
        ),
        FuelStation(
            id: "33210001",
            latitude: 44.553,
            longitude: -0.248,
            cp: "33210",
            city: "Langon",
            address: "Rue Jules Ferry",
            prices: [
                FuelPrice(type: .gazole, price: 1.999, updatedAtRaw: "2026-03-19 10:10:00"),
                FuelPrice(type: .e10, price: 1.839, updatedAtRaw: "2026-03-19 10:10:00")
            ],
            updatedAtRaw: "2026-03-19 10:10:00"
        )
    ]
}
