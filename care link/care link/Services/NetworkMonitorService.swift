import Foundation
import Network

@Observable
final class NetworkMonitorService {
    var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "carelink.network.monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
