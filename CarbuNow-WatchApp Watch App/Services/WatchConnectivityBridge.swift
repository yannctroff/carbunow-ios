//
//  WatchConnectivityBridge.swift
//  CarbuNow
//
//  Created by Yann CATTARIN on 31/03/2026.
//


import Foundation
import WatchConnectivity

extension Notification.Name {
    static let watchDefaultFuelDidChange = Notification.Name("watchDefaultFuelDidChange")
}

final class WatchConnectivityBridge: NSObject {
    static let shared = WatchConnectivityBridge()

    private let defaultFuelKey = SharedDefaults.defaultFuelKey
    private var pendingApplicationContext: [String: Any]?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity non supporté")
            return
        }

        let session = WCSession.default

        if session.delegate == nil {
            session.delegate = self
        }

        if session.activationState != .activated {
            print("⌚️ WCSession activate()")
            session.activate()
        } else {
            print("✅ WCSession déjà activée")
            applyIfAvailable(from: session)
            flushPendingContextIfPossible()
        }
    }

    func syncDefaultFuel(_ fuel: FuelType) {
        let payload: [String: Any] = [
            defaultFuelKey: fuel.rawValue
        ]

        pendingApplicationContext = payload
        flushPendingContextIfPossible()
    }

    private func flushPendingContextIfPossible() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        guard session.activationState == .activated else {
            print("⏳ WCSession pas encore activée, contexte en attente")
            return
        }

        guard let payload = pendingApplicationContext else { return }

        #if os(iOS)
        guard session.isPaired else {
            print("⚠️ Aucune Apple Watch jumelée")
            return
        }

        guard session.isWatchAppInstalled else {
            print("⚠️ App Watch non installée")
            return
        }
        #endif

        do {
            try session.updateApplicationContext(payload)
            print("✅ Contexte WatchConnectivity envoyé: \(payload)")
            pendingApplicationContext = nil
        } catch {
            print("⚠️ WatchConnectivity flush error: \(error.localizedDescription)")
        }
    }

    private func applyIfAvailable(from session: WCSession) {
        let context = session.receivedApplicationContext
        if context.isEmpty {
            print("ℹ️ Aucun contexte reçu à l’activation")
        } else {
            print("📦 Contexte reçu à l’activation: \(context)")
            apply(applicationContext: context)
        }
    }

    private func apply(applicationContext: [String: Any]) {
        guard let rawFuel = applicationContext[defaultFuelKey] as? String,
              let fuel = FuelType(rawValue: rawFuel) else {
            print("⚠️ Application context invalide: \(applicationContext)")
            return
        }

        SharedDefaults.shared.set(fuel.rawValue, forKey: defaultFuelKey)
        UserDefaults.standard.set(fuel.rawValue, forKey: defaultFuelKey)

        print("📥 Carburant reçu via WatchConnectivity: \(fuel.rawValue)")

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .watchDefaultFuelDidChange,
                object: nil,
                userInfo: [self.defaultFuelKey: fuel.rawValue]
            )
        }
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⚠️ WCSession activation error: \(error.localizedDescription)")
        }

        print("⌚️ WCSession activation state: \(activationState.rawValue)")

        if activationState == .activated {
            applyIfAvailable(from: session)
            flushPendingContextIfPossible()
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        print("📩 didReceiveApplicationContext: \(applicationContext)")
        apply(applicationContext: applicationContext)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("ℹ️ WCSession devenue inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("ℹ️ WCSession désactivée, réactivation")
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("⌚️ Watch state changed | paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)")
        flushPendingContextIfPossible()
    }
    #endif
}
