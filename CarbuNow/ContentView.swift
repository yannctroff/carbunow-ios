import SwiftUI

struct ContentView: View {
    @State private var showsLaunchOverlay = true

    var body: some View {
        ZStack {
            HomeView()

            if showsLaunchOverlay {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(900))

            withAnimation(.easeOut(duration: 0.25)) {
                showsLaunchOverlay = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(FavoritesStore())
        .environmentObject(StationsViewModel())
}
