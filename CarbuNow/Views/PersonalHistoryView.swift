import SwiftUI

struct PersonalHistoryView: View {
    @EnvironmentObject private var viewModel: StationsViewModel
    @ObservedObject private var historyStore = StationHistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStation: FuelStation?
    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        List {
            if historyStore.entries.isEmpty {
                ContentUnavailableView(
                    "Aucun historique",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Les stations que tu consultes apparaîtront ici.")
                )
            } else {
                Section("Récents") {
                    ForEach(historyStore.recentEntries.prefix(10)) { entry in
                        historyRow(for: entry)
                    }
                }

                Section("Les plus consultées") {
                    ForEach(historyStore.mostViewedEntries.prefix(10)) { entry in
                        historyRow(for: entry, showsCount: true)
                    }
                }
            }
        }
        .navigationTitle("Historique personnel")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Effacer") {
                    historyStore.clear()
                }
                .disabled(historyStore.entries.isEmpty)
            }

            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(item: $selectedStation) { station in
            NavigationStack {
                StationDetailView(station: station, showsCloseButton: true)
            }
        }
    }

    @ViewBuilder
    private func historyRow(for entry: StationHistoryEntry, showsCount: Bool = false) -> some View {
        Button {
            if let resolvedStation = resolveStation(for: entry) {
                selectedStation = resolvedStation
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if showsCount {
                        Text("\(entry.viewCount)x")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text(formattedDate(entry.lastViewedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let price = entry.latestPrices[viewModel.selectedFuel.rawValue] {
                        Text(String(format: "%.3f €/L", price))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func resolveStation(for entry: StationHistoryEntry) -> FuelStation? {
        let candidates = viewModel.allStations + viewModel.listStations
        return candidates.first(where: { $0.id == entry.stationID })
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
