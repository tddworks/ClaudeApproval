import Foundation

/// Represents a permission request from Claude Code awaiting approval
@Observable
public final class ApprovalRequest: Identifiable, Sendable {
    public let id: String
    public let tool: String
    public let description: String
    public let input: [String: String]
    public let timestamp: Date

    public init(
        id: String,
        tool: String,
        description: String,
        input: [String: String] = [:],
        timestamp: Date = .now
    ) {
        self.id = id
        self.tool = tool
        self.description = description
        self.input = input
        self.timestamp = timestamp
    }
}

extension ApprovalRequest: Equatable {
    public static func == (lhs: ApprovalRequest, rhs: ApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }
}

extension ApprovalRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}