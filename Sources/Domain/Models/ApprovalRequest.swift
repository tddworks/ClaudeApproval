import Foundation

/// Represents a permission request from Claude Code awaiting approval
@Observable
public final class ApprovalRequest: Identifiable, @unchecked Sendable {
    public let id: String
    public let tool: String
    public let description: String
    public let timestamp: Date
    public private(set) var status: RequestStatus
    public private(set) var resolvedAt: Date?

    /// Timeout in seconds before request expires (default 120)
    public static let defaultTimeout: TimeInterval = 120

    public init(
        id: String,
        tool: String,
        description: String,
        timestamp: Date = .now,
        status: RequestStatus = .pending
    ) {
        self.id = id
        self.tool = tool
        self.description = description
        self.timestamp = timestamp
        self.status = status
    }

    // MARK: - Computed Properties

    /// Time elapsed since request was created
    public var timeElapsed: TimeInterval {
        Date.now.timeIntervalSince(timestamp)
    }

    /// Whether the request has exceeded its timeout
    public var isExpired: Bool {
        status == .pending && timeElapsed > Self.defaultTimeout
    }

    /// Whether the request is still actionable
    public var isPending: Bool {
        status == .pending && !isExpired
    }

    /// Icon name for the tool type
    public var toolIcon: String {
        switch tool {
        case "Bash": "terminal"
        case "Edit": "pencil"
        case "Write": "doc.text"
        case "Read": "eye"
        default: "questionmark.circle"
        }
    }

    /// Display-friendly time since request was created
    public var timeAgo: String {
        let elapsed = Int(timeElapsed)
        if elapsed < 60 {
            return "\(elapsed)s ago"
        } else {
            return "\(elapsed / 60)m ago"
        }
    }

    // MARK: - Behavior Methods

    /// Approve this request
    /// - Returns: true if approved, false if already resolved or expired
    @discardableResult
    public func approve() -> Bool {
        guard status == .pending else { return false }
        guard !isExpired else {
            status = .expired
            resolvedAt = Date.now
            return false
        }
        status = .approved
        resolvedAt = Date.now
        return true
    }

    /// Decline this request
    /// - Returns: true if declined, false if already resolved or expired
    @discardableResult
    public func decline() -> Bool {
        guard status == .pending else { return false }
        guard !isExpired else {
            status = .expired
            resolvedAt = Date.now
            return false
        }
        status = .declined
        resolvedAt = Date.now
        return true
    }

    /// Mark as expired if timeout exceeded
    /// - Returns: true if marked expired, false if already resolved
    @discardableResult
    public func markExpiredIfNeeded() -> Bool {
        guard status == .pending && timeElapsed > Self.defaultTimeout else {
            return false
        }
        status = .expired
        resolvedAt = Date.now
        return true
    }
}

// MARK: - Equatable

extension ApprovalRequest: Equatable {
    public static func == (lhs: ApprovalRequest, rhs: ApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ApprovalRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Codable

extension ApprovalRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case id, tool, description, timestamp, status, resolvedAt
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let tool = try container.decode(String.self, forKey: .tool)
        let description = try container.decode(String.self, forKey: .description)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let status = try container.decodeIfPresent(RequestStatus.self, forKey: .status) ?? .pending

        self.init(id: id, tool: tool, description: description, timestamp: timestamp, status: status)
        self.resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tool, forKey: .tool)
        try container.encode(description, forKey: .description)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(resolvedAt, forKey: .resolvedAt)
    }
}
