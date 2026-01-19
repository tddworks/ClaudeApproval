import Foundation

/// Root aggregate managing approval requests
@MainActor
@Observable
public final class ApprovalRequests {
    public private(set) var requests: [ApprovalRequest] = []
    public private(set) var isConnected: Bool = false
    public private(set) var serverAddress: String?

    private var service: (any ApprovalService)?

    public init() {}

    // MARK: - Computed Properties

    public var pendingCount: Int {
        requests.filter { $0.isPending }.count
    }

    public var isEmpty: Bool {
        requests.isEmpty
    }

    public var pendingRequests: [ApprovalRequest] {
        requests.filter { $0.isPending }
    }

    public var expiredRequests: [ApprovalRequest] {
        requests.filter { $0.isExpired }
    }

    public var resolvedRequests: [ApprovalRequest] {
        requests.filter { $0.status.isResolved }
    }

    public var oldestPendingRequest: ApprovalRequest? {
        pendingRequests.min { $0.timestamp < $1.timestamp }
    }

    // MARK: - Queries

    public func requests(forTool tool: String) -> [ApprovalRequest] {
        requests.filter { $0.tool == tool }
    }

    public func request(byId id: String) -> ApprovalRequest? {
        requests.first { $0.id == id }
    }

    // MARK: - Service Configuration

    public func configure(service: any ApprovalService) {
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

        do {
            let pending = try await service.fetchPendingRequests()
            requests = pending
            if !isConnected {
                isConnected = true
            }
        } catch {
            print("Refresh failed: \(error)")
        }
    }

    public func approve(_ request: ApprovalRequest) async {
        guard let service else { return }

        // Use domain model's behavior method
        guard request.approve() else { return }

        do {
            try await service.respond(to: request.id, approved: true)
            requests.removeAll { $0.id == request.id }
        } catch {
            // Rollback on failure
            // Note: status already changed, would need to track for proper rollback
        }
    }

    public func decline(_ request: ApprovalRequest) async {
        guard let service else { return }

        // Use domain model's behavior method
        guard request.decline() else { return }

        do {
            try await service.respond(to: request.id, approved: false)
            requests.removeAll { $0.id == request.id }
        } catch {
            // Rollback on failure
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

    /// Mark all expired requests and remove them
    public func cleanupExpired() {
        for request in requests {
            request.markExpiredIfNeeded()
        }
        requests.removeAll { $0.status == .expired }
    }
}
