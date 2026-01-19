import Foundation
import Testing
@testable import Domain

@Suite("ApprovalRequest")
struct ApprovalRequestTests {

    // MARK: - Creation

    @Test func `request starts with pending status`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello"
        )

        #expect(request.status == .pending)
        #expect(request.resolvedAt == nil)
    }

    @Test func `request stores tool and description`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Edit",
            description: "Modify: file.swift"
        )

        #expect(request.tool == "Edit")
        #expect(request.description == "Modify: file.swift")
    }

    // MARK: - Approval

    @Test func `user can approve a pending request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: npm install"
        )

        let success = request.approve()

        #expect(success == true)
        #expect(request.status == .approved)
        #expect(request.resolvedAt != nil)
    }

    @Test func `user cannot approve an already approved request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: npm install"
        )
        request.approve()

        let success = request.approve()

        #expect(success == false)
        #expect(request.status == .approved)
    }

    @Test func `user cannot approve a declined request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: npm install"
        )
        request.decline()

        let success = request.approve()

        #expect(success == false)
        #expect(request.status == .declined)
    }

    // MARK: - Decline

    @Test func `user can decline a pending request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: rm -rf"
        )

        let success = request.decline()

        #expect(success == true)
        #expect(request.status == .declined)
        #expect(request.resolvedAt != nil)
    }

    @Test func `user cannot decline an already declined request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: rm -rf"
        )
        request.decline()

        let success = request.decline()

        #expect(success == false)
        #expect(request.status == .declined)
    }

    @Test func `user cannot decline an approved request`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: npm install"
        )
        request.approve()

        let success = request.decline()

        #expect(success == false)
        #expect(request.status == .approved)
    }

    // MARK: - Expiration

    @Test func `request is not expired when within timeout`() {
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: Date.now
        )

        #expect(request.isExpired == false)
        #expect(request.isPending == true)
    }

    @Test func `request is expired when past timeout`() {
        let pastDate = Date.now.addingTimeInterval(-150) // 150 seconds ago
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: pastDate
        )

        #expect(request.isExpired == true)
        #expect(request.isPending == false)
    }

    @Test func `approving expired request marks it as expired`() {
        let pastDate = Date.now.addingTimeInterval(-150) // Past timeout
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: pastDate
        )

        let success = request.approve()

        #expect(success == false)
        #expect(request.status == .expired)
    }

    @Test func `declining expired request marks it as expired`() {
        let pastDate = Date.now.addingTimeInterval(-150) // Past timeout
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: pastDate
        )

        let success = request.decline()

        #expect(success == false)
        #expect(request.status == .expired)
    }

    @Test func `markExpiredIfNeeded transitions pending to expired`() {
        let pastDate = Date.now.addingTimeInterval(-150)
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: pastDate
        )

        let marked = request.markExpiredIfNeeded()

        #expect(marked == true)
        #expect(request.status == .expired)
    }

    @Test func `markExpiredIfNeeded does nothing for resolved requests`() {
        let pastDate = Date.now.addingTimeInterval(-150)
        let request = ApprovalRequest(
            id: "test-1",
            tool: "Bash",
            description: "Run: echo hello",
            timestamp: pastDate,
            status: .approved
        )

        let marked = request.markExpiredIfNeeded()

        #expect(marked == false)
        #expect(request.status == .approved)
    }

    // MARK: - Computed Properties

    @Test func `toolIcon returns correct icon for Bash`() {
        let request = ApprovalRequest(id: "1", tool: "Bash", description: "")
        #expect(request.toolIcon == "terminal")
    }

    @Test func `toolIcon returns correct icon for Edit`() {
        let request = ApprovalRequest(id: "1", tool: "Edit", description: "")
        #expect(request.toolIcon == "pencil")
    }

    @Test func `toolIcon returns correct icon for Write`() {
        let request = ApprovalRequest(id: "1", tool: "Write", description: "")
        #expect(request.toolIcon == "doc.text")
    }

    @Test func `toolIcon returns correct icon for Read`() {
        let request = ApprovalRequest(id: "1", tool: "Read", description: "")
        #expect(request.toolIcon == "eye")
    }

    @Test func `toolIcon returns fallback for unknown tool`() {
        let request = ApprovalRequest(id: "1", tool: "Unknown", description: "")
        #expect(request.toolIcon == "questionmark.circle")
    }

    // MARK: - Equality

    @Test func `requests with same id are equal`() {
        let request1 = ApprovalRequest(id: "same-id", tool: "Bash", description: "cmd1")
        let request2 = ApprovalRequest(id: "same-id", tool: "Edit", description: "cmd2")

        #expect(request1 == request2)
    }

    @Test func `requests with different ids are not equal`() {
        let request1 = ApprovalRequest(id: "id-1", tool: "Bash", description: "cmd")
        let request2 = ApprovalRequest(id: "id-2", tool: "Bash", description: "cmd")

        #expect(request1 != request2)
    }
}