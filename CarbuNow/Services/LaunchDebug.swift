import UIKit

enum LaunchDebug {
    static func log(context: String) {
        #if DEBUG
        let bundle = Bundle.main
        let screen = UIScreen.main
        let bundleID = bundle.bundleIdentifier ?? "unknown"
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let launchStoryboard = bundle.infoDictionary?["UILaunchStoryboardName"] as? String ?? "nil"

        print("[LaunchDebug] context=\(context)")
        print("[LaunchDebug] bundleID=\(bundleID) version=\(version) build=\(build)")
        print("[LaunchDebug] launchStoryboard=\(launchStoryboard)")
        print("[LaunchDebug] screenBounds=\(screen.bounds) nativeBounds=\(screen.nativeBounds) scale=\(screen.scale) nativeScale=\(screen.nativeScale)")

        if let image = UIImage(named: "LaunchLogo", in: bundle, compatibleWith: nil) {
            print("[LaunchDebug] UIImage LaunchLogo OK size=\(image.size) scale=\(image.scale)")
        } else {
            print("[LaunchDebug] UIImage LaunchLogo MISSING")
        }

        if let carURL = bundle.url(forResource: "Assets", withExtension: "car") {
            print("[LaunchDebug] Assets.car=\(carURL.path)")
        } else {
            print("[LaunchDebug] Assets.car MISSING")
        }

        if let storyboardURL = bundle.url(forResource: launchStoryboard, withExtension: "storyboardc") {
            print("[LaunchDebug] storyboardc=\(storyboardURL.path)")
        } else {
            print("[LaunchDebug] storyboardc MISSING for \(launchStoryboard)")
        }
        #endif
    }
}
