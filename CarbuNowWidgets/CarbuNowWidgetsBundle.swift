import WidgetKit
import SwiftUI

@main
struct CarbuNowWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CheapestAroundWidget()
        NearestStationWidget()
        ActiveAlertsWidget()
    }
}
