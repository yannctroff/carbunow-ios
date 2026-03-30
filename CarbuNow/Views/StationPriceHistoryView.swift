import SwiftUI
import Charts

struct StationPriceHistoryView: View {
    let stationID: String
    let fuelType: String
    let fuelDisplayName: String

    @State private var history: [FuelPriceHistoryPoint] = []
    @State private var selectedPeriod = 7
    @State private var isLoading = false
    @State private var selectedPoint: FuelPriceHistoryPoint?

    private var pricedHistory: [FuelPriceHistoryPoint] {
        let sorted = history
            .filter { $0.price != nil }
            .sorted { $0.timestamp < $1.timestamp }

        var result: [FuelPriceHistoryPoint] = []
        let calendar = Calendar.current

        for point in sorted {
            guard let price = point.price else { continue }

            guard let last = result.last, let lastPrice = last.price else {
                result.append(point)
                continue
            }

            let sameDay = calendar.isDate(point.date, inSameDayAs: last.date)

            if sameDay {
                if price != lastPrice {
                    result.append(point)
                }
            } else {
                result.append(point)
            }
        }

        return result
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historique des prix")
                        .font(.headline)

                    Text(fuelDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let selectedPoint, let selectedPrice = selectedPoint.price {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedDate(selectedPoint.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(selectedPrice, specifier: "%.3f")€")
                            .font(.headline.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Picker("", selection: $selectedPeriod) {
                Text("7j").tag(7)
                Text("30j").tag(30)
                Text("90j").tag(90)
                Text("365j").tag(365)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) {
                selectedPoint = nil
                load()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if pricedHistory.isEmpty {
                Text("Aucune donnée")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Chart {
                        ForEach(pricedHistory) { point in
                            if let price = point.price {
                                AreaMark(
                                    x: .value("Date", point.date),
                                    yStart: .value("Base", chartMinY),
                                    yEnd: .value("Prix", price)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue.opacity(0.15))

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Prix", price)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue)

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Prix", price)
                                )
                                .foregroundStyle(.blue)
                            }
                        }

                        if let selectedPoint {
                            RuleMark(x: .value("Date sélectionnée", selectedPoint.date))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
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
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else {
                                                return
                                            }

                                            let plotRect = geometry[plotFrame]
                                            let xPosition = value.location.x - plotRect.origin.x

                                            guard xPosition >= 0, xPosition <= plotRect.size.width else {
                                                selectedPoint = nil
                                                return
                                            }

                                            if let date: Date = proxy.value(atX: xPosition) {
                                                selectedPoint = nearestPoint(to: date)
                                            }
                                        }
                                        .onEnded { _ in
                                            selectedPoint = nil
                                        }
                                )
                        }
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
            selectedPoint = nil
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

    private func nearestPoint(to date: Date) -> FuelPriceHistoryPoint? {
        pricedHistory.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
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
                    selectedPoint = nil
                    isLoading = false
                }
            } catch {
                print("Erreur historique:", error)

                await MainActor.run {
                    history = []
                    selectedPoint = nil
                    isLoading = false
                }
            }
        }
    }
}
