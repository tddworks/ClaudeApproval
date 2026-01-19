import Foundation

/// Status of an approval request in its lifecycle
public enum RequestStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case declined
    case expired

    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .approved: "Approved"
        case .declined: "Declined"
        case .expired: "Expired"
        }
    }

    public var isResolved: Bool {
        switch self {
        case .pending: false
        case .approved, .declined, .expired: true
        }
    }
}
