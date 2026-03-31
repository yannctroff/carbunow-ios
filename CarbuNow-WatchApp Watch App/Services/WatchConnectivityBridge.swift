import Foundation
import WatchConnectivity

extension Notification.Name {
    static let watchDefaultFuelDidChange = Notification.Name("watchDefaultFuelDidChange")
}

final class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()

    private let defaultFuelKey = SharedDefaults.defaultFuelKey

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func syncDefaultFuel(_ fuel: FuelType) {
        guard WCSession.isSupported() else { return }

        let payload: [String: Any] = [
            defaultFuelKey: fuel.rawValue
        ]

        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            print("⚠️ WatchConnectivity syncDefaultFuel error: \(error.localizedDescription)")
        }
    }

    private func apply(applicationContext: [String: Any]) {
        guard let rawFuel = applicationContext[defaultFuelKey] as? String,
              let fuel = FuelType(rawValue: rawFuel) else {
            return
        }

        SharedDefaults.shared.set(fuel.rawValue, forKey: defaultFuelKey)

        NotificationCenter.default.post(
            name: .watchDefaultFuelDidChange,
            object: nil,
            userInfo: [defaultFuelKey: fuel.rawValue]
        )
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) { }
    #endif

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⚠️ WatchConnectivity activation error: \(error.localizedDescription)")
        }

        if activationState == .activated {
            apply(applicationContext: session.receivedApplicationContext)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        apply(applicationContext: applicationContext)
    }
}