//
//  NetworkMonitor.swift
//  MedJourney
//
//  Core Networking Layer — Connectivity monitoring
//

import Foundation
import Network

/// Monitors network connectivity using `NWPathMonitor`.
///
/// Use this to reactively update UI based on connection status,
/// or to prevent network requests when offline.
///
/// Usage:
/// ```swift
/// // In a View:
/// @State private var networkMonitor = NetworkMonitor()
///
/// var body: some View {
///     if !networkMonitor.isConnected {
///         Text("No internet connection")
///     }
/// }
/// ```
@Observable
final class NetworkMonitor {

    // MARK: - Published Properties

    /// Whether the device currently has network connectivity.
    private(set) var isConnected: Bool = true

    /// The current connection type (wifi, cellular, etc.).
    private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Connection Type

    /// Describes the type of network connection.
    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case wiredEthernet = "Ethernet"
        case unknown = "Unknown"
    }

    // MARK: - Private

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.medjourney.networkmonitor")

    // MARK: - Initialization

    init() {
        monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .unknown
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private Helpers

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
}
