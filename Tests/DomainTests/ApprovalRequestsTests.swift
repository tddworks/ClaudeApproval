import Foundation
import Testing
@testable import Domain

@Suite("ApprovalRequests")
@MainActor
struct ApprovalRequestsTests {

    // MARK: - Initial State

    @Test func `starts empty with no connection`() {
        let requests = ApprovalRequests()

        #expect(requests.isEmpty == true)
        #expect(requests.pendingCount == 0)
        #expect(requests.isConnected == false)
        #expect(requests.serverAddress == nil)
    }

    // MARK: - Adding Requests

    @Test func `user can add a request`() {
        let requests = ApprovalRequests()
        let request = ApprovalRequest(id: "1", tool: "Bash", description: "cmd")

        requests.add(request)

        #expect(requests.isEmpty == false)
        #expect(requests.pendingCount == 1)
    }

    @Test func `adding duplicate request is ignored`() {
        let requests = ApprovalRequests()
        let request = ApprovalRequest(id: "1", tool: "Bash", description: "cmd")

        requests.add(request)
        requests.add(request)

        #expect(requests.requests.count == 1)
    }

    @Test func `user can add multiple requests`() {
        let requests = ApprovalRequests()

        requests.add(ApprovalRequest(id: "1", tool: "Bash", description: "cmd1"))
        requests.add(ApprovalRequest(id: "2", tool: "Edit", description: "cmd2"))
        requests.add(ApprovalRequest(id: "3", tool: "Write", description: "cmd3"))

        #expect(requests.requests.count == 3)
        #expect(requests.pendingCount == 3)
    }

    // MARK: - Removing Requests

    @Test func `user can remove a request`() {
        let requests = ApprovalRequests()
        let request = ApprovalRequest(id: "1", tool: "Bash", description: "cmd")
        requests.add(request)

        requests.remove(request)

        #expect(requests.isEmpty == true)
    }

    @Test func `removing non-existent request is safe`() {
        let requests = ApprovalRequests()
        let request = ApprovalRequest(id: "1", tool: "Bash", description: "cmd")

        requests.remove(request)

        #expect(requests.isEmpty == true)
    }

    // MARK: - Queries

    @Test func `can find request by id`() {
        let requests = ApprovalRequests()
        requests.add(ApprovalRequest(id: "abc", tool: "Bash", description: "cmd1"))
        requests.add(ApprovalRequest(id: "def", tool: "Edit", description: "cmd2"))

        let found = requests.request(byId: "abc")

        #expect(found != nil)
        #expect(found?.id == "abc")
    }

    @Test func `returns nil for non-existent id`() {
        let requests = ApprovalRequests()
        requests.add(ApprovalRequest(id: "abc", tool: "Bash", description: "cmd"))

        let found = requests.request(byId: "xyz")

        #expect(found == nil)
    }

    @Test func `can filter requests by tool`() {
        let requests = ApprovalRequests()
        requests.add(ApprovalRequest(id: "1", tool: "Bash", description: "cmd1"))
        requests.add(ApprovalRequest(id: "2", tool: "Edit", description: "cmd2"))
        requests.add(ApprovalRequest(id: "3", tool: "Bash", description: "cmd3"))

        let bashRequests = requests.requests(forTool: "Bash")

        #expect(bashRequests.count == 2)
    }

    // MARK: - Pending vs Expired

    @Test func `pendingRequests excludes expired`() {
        let requests = ApprovalRequests()

        // Add fresh request
        requests.add(ApprovalRequest(id: "1", tool: "Bash", description: "fresh"))

        // Add expired request
        let pastDate = Date.now.addingTimeInterval(-150)
        requests.add(ApprovalRequest(
            id: "2",
            tool: "Edit",
            description: "expired",
            timestamp: pastDate
        ))

        #expect(requests.pendingRequests.count == 1)
        #expect(requests.expiredRequests.count == 1)
    }

    @Test func `oldestPendingRequest returns oldest fresh request`() {
        let requests = ApprovalRequests()

        let older = Date.now.addingTimeInterval(-30) // 30 seconds ago
        let newer = Date.now.addingTimeInterval(-10) // 10 seconds ago

        requests.add(ApprovalRequest(id: "newer", tool: "Bash", description: "cmd", timestamp: newer))
        requests.add(ApprovalRequest(id: "older", tool: "Edit", description: "cmd", timestamp: older))

        let oldest = requests.oldestPendingRequest

        #expect(oldest?.id == "older")
    }

    // MARK: - Cleanup

    @Test func `cleanupExpired removes expired requests`() {
        let requests = ApprovalRequests()

        // Add fresh request
        requests.add(ApprovalRequest(id: "1", tool: "Bash", description: "fresh"))

        // Add expired request
        let pastDate = Date.now.addingTimeInterval(-150)
        requests.add(ApprovalRequest(
            id: "2",
            tool: "Edit",
            description: "expired",
            timestamp: pastDate
        ))

        #expect(requests.requests.count == 2)

        requests.cleanupExpired()

        #expect(requests.requests.count == 1)
        #expect(requests.requests.first?.id == "1")
    }

    // MARK: - Connection Status

    @Test func `can update connection status`() {
        let requests = ApprovalRequests()

        requests.updateConnectionStatus(connected: true, address: "192.168.1.1:8754")

        #expect(requests.isConnected == true)
        #expect(requests.serverAddress == "192.168.1.1:8754")
    }

    @Test func `resolved requests excludes pending`() {
        let requests = ApprovalRequests()

        let pendingRequest = ApprovalRequest(id: "1", tool: "Bash", description: "pending")
        let approvedRequest = ApprovalRequest(id: "2", tool: "Edit", description: "approved")
        approvedRequest.approve()

        requests.add(pendingRequest)
        requests.add(approvedRequest)

        #expect(requests.resolvedRequests.count == 1)
        #expect(requests.resolvedRequests.first?.id == "2")
    }
}
