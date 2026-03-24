import Foundation

final class FuelAPIService {
    func fetchStations() async throws -> [FuelStation] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return PreviewData.stations
    }
}