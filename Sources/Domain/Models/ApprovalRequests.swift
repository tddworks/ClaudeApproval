import Foundation

/// Root aggregate managing approval requests
@MainActor
@Observable
public final class ApprovalRequests {
    public private(set) var requests: [ApprovalRequest] = []
    public private(set) var isConnected: Bool = false
    public private(set) var serverAddress: String?

    private var service: ApprovalService?

    public init() {}

    public var pendingCount: Int {
        requests.count
    }

    public var isEmpty: Bool {
        requests.isEmpty
    }

    // MARK: - Service Configuration

    public func configure(service: ApprovalService) {
        self.service = service
    }

    // MARK: - Connection

    public func connect() async {
        guard let service else { return }
        await service.startBrowsing()
    }

    public func disconnect() async {
        guard let service else { return }
        await service.stopBrowsing()
        isConnected = false
        serverAddress = nil
    }

    public func updateConnectionStatus(connected: Bool, address: String?) {
        isConnected = connected
        serverAddress = address
    }

    // MARK: - Request Management

    public func refresh() async {
        guard let service else { return }

        // Try to fetch even if not "connected" - the HTTP request will work
        // if we have a valid server address from Bonjour discovery
        do {
            let pending = try await service.fetchPendingRequests()
            requests = pending
            // If fetch succeeded, we're effectively connected
            if !isConnected {
                isConnected = true
            }
        } catch {
            // Fetch failed - could be not connected or network error
            // Don't clear requests immediately, they might still be valid
            print("Refresh failed: \(error)")
        }
    }

    public func approve(_ request: ApprovalRequest) async {
        guard let service else { return }
        do {
            try await service.respond(to: request.id, approved: true)
            requests.removeAll { $0.id == request.id }
        } catch {
            // Handle error silently for POC
        }
    }

    public func decline(_ request: ApprovalRequest) async {
        guard let service else { return }
        do {
            try await service.respond(to: request.id, approved: false)
            requests.removeAll { $0.id == request.id }
        } catch {
            // Handle error silently for POC
        }
    }

    public func add(_ request: ApprovalRequest) {
        if !requests.contains(where: { $0.id == request.id }) {
            requests.append(request)
        }
    }

    public func remove(_ request: ApprovalRequest) {
        requests.removeAll { $0.id == request.id }
    }
}