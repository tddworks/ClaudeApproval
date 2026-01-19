import Foundation

// TODO: Add @Mockable when Mockable dependency is added
// @Mockable
/// Protocol for approval service communication
public protocol ApprovalService: Sendable {
    /// Start browsing for Claude approval servers via Bonjour
    func startBrowsing() async

    /// Stop browsing for servers
    func stopBrowsing() async

    /// Fetch pending approval requests from the connected server
    func fetchPendingRequests() async throws -> [ApprovalRequest]

    /// Respond to an approval request
    func respond(to requestId: String, approved: Bool) async throws
}