import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(FavoritesStore())
        .environmentObject(StationsViewModel())
}
