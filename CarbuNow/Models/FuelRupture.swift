//
//  FuelRupture.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 25/03/2026.
//


import Foundation

struct FuelRupture: Decodable, Hashable {
    let type: FuelType
    let startedAtRaw: String?
    let endedAtRaw: String?
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case fuel
        case startedAtRaw = "started_at"
        case endedAtRaw = "ended_at"
        case kind
    }

    init(type: FuelType, startedAtRaw: String? = nil, endedAtRaw: String? = nil, kind: String? = nil) {
        self.type = type
        self.startedAtRaw = startedAtRaw
        self.endedAtRaw = endedAtRaw
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawFuel = try container.decode(String.self, forKey: .fuel)
        guard let fuelType = FuelType.fromAPIValue(rawFuel) else {
            throw DecodingError.dataCorruptedError(
                forKey: .fuel,
                in: container,
                debugDescription: "Carburant en rupture inconnu : \(rawFuel)"
            )
        }

        self.type = fuelType
        self.startedAtRaw = try container.decodeIfPresent(String.self, forKey: .startedAtRaw)
        self.endedAtRaw = try container.decodeIfPresent(String.self, forKey: .endedAtRaw)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
    }

    var isActive: Bool {
        (endedAtRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
