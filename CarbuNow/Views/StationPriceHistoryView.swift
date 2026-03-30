import SwiftUI
import Charts

struct StationPriceHistoryView: View {
    let stationID: String
    let fuelType: String
    let fuelDisplayName: String

    @State private var history: [FuelPriceHistoryPoint] = []
    @State private var selectedPeriod = 7
    @State private var isLoading = false

    private var pricedHistory: [FuelPriceHistoryPoint] {
        history
            .filter { $0.price != nil }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var latestPrice: Double? {
        pricedHistory.last?.price
    }

    private var minPrice: Double? {
        pricedHistory.compactMap(\.price).min()
    }

    private var maxPrice: Double? {
        pricedHistory.compactMap(\.price).max()
    }

    private var priceDelta: Double? {
        guard
            let first = pricedHistory.first?.price,
            let last = pricedHistory.last?.price
        else { return nil }

        return last - first
    }

    private var chartMinY: Double {
        guard let minPrice, let maxPrice else { return 0 }

        let range = maxPrice - minPrice
        let padding = max(0.003, range * 0.15)

        return minPrice - padding
    }

    private var chartMaxY: Double {
        guard let minPrice, let maxPrice else { return 2 }

        let range = maxPrice - minPrice
        let padding = max(0.003, range * 0.15)

        return maxPrice + padding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Historique des prix")
                .font(.headline)

            Text(fuelDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedPeriod) {
                Text("7j").tag(7)
                Text("30j").tag(30)
                Text("90j").tag(90)
                Text("365j").tag(365)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) {
                load()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            else if pricedHistory.isEmpty {
                Text("Aucune donnée")
                    .foregroundStyle(.secondary)
            }
            else {
                VStack(alignment: .leading, spacing: 14) {

                    Chart {
                        ForEach(pricedHistory) { point in
                            if let price = point.price {

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Prix", price)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue)

                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Base", chartMinY),
                                    yEnd: .value("Prix", price)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue.opacity(0.15))

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Prix", price)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    .chartYScale(domain: chartMinY...chartMaxY)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let price = value.as(Double.self) {
                                    Text("\(price, specifier: "%.3f")€")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .frame(height: 220)

                    HStack(spacing: 16) {
                        statBlock(title: "Dernier", value: latestPrice)
                        statBlock(title: "Min", value: minPrice)
                        statBlock(title: "Max", value: maxPrice)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Variation")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let delta = priceDelta {
                                Text("\(delta >= 0 ? "+" : "")\(delta, specifier: "%.3f")€")
                                    .bold()
                                    .foregroundStyle(delta < 0 ? .green : (delta > 0 ? .red : .primary))
                            } else {
                                Text("—")
                                    .bold()
                            }
                        }
                    }

                    Text("\(pricedHistory.count) point(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            load()
        }
        .onChange(of: fuelType) {
            load()
        }
    }

    @ViewBuilder
    private func statBlock(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let value {
                Text("\(value, specifier: "%.3f")€")
                    .bold()
            } else {
                Text("—")
                    .bold()
            }
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
                    history = []
                    isLoading = false
                }
            }
        }
    }
}