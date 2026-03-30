import SwiftUI

struct StationPriceHistoryView: View {
    let stationID: String
    let fuelType: String

    @State private var history: [FuelPriceHistoryPoint] = []
    @State private var selectedPeriod = 7
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Historique des prix")
                .font(.headline)

            Picker("", selection: $selectedPeriod) {
                Text("7j").tag(7)
                Text("30j").tag(30)
                Text("90j").tag(90)
                Text("365j").tag(365)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) { _ in
                load()
            }

            if isLoading {
                ProgressView()
            } else if history.isEmpty {
                Text("Aucune donnée")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading) {
                    Text("Dernier prix: \(history.last?.price ?? 0, specifier: "%.3f")€")
                    Text("Points: \(history.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            load()
        }
    }

    private func load() {
        isLoading = true

        Task {
            do {
                let result = try await FuelAPIService.shared.fetchHistory(
                    stationID: stationID,
                    fuelType: fuelType,
                    days: selectedPeriod
                )

                await MainActor.run {
                    history = result
                    isLoading = false
                }
            } catch {
                print("Erreur historique:", error)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}