import Foundation
import Combine
import MapKit

final class FranceAddressSearchCompleter: NSObject, ObservableObject {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = Self.franceSearchRegion
    }

    func update(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= 2 else {
            completions = []
            completer.queryFragment = ""
            return
        }

        completer.queryFragment = trimmedQuery
    }

    func clear() {
        completions = []
        completer.queryFragment = ""
    }

    static let franceSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.7111, longitude: 1.7191),
        span: MKCoordinateSpan(latitudeDelta: 13.2, longitudeDelta: 14.8)
    )

    static func search(query: String) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        request.region = franceSearchRegion

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.franceAddressResults
    }

    static func search(completion: MKLocalSearchCompletion) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        request.region = franceSearchRegion

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.franceAddressResults
    }
}

extension FranceAddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = Array(completer.results.prefix(8))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.completions = []
        }
    }
}

extension MKLocalSearchCompletion {
    var completionIdentifier: String {
        "\(title)|\(subtitle)"
    }

    var displayTitle: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

private extension Array where Element == MKMapItem {
    var franceAddressResults: [MKMapItem] {
        filter { item in
            let placemark = item.placemark
            return placemark.isoCountryCode == "FR" || placemark.country == "France"
        }
    }
}
