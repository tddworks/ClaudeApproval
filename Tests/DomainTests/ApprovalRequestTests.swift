import Testing
@testable import Domain

@Suite("ApprovalRequest Tests")
struct ApprovalRequestTests {

    @Test("ApprovalRequest can be created with all properties")
    func testCreation() {
        let request = ApprovalRequest(
            id: "test-123",
            tool: "Bash",
            description: "ls -la",
            input: ["command": "ls -la"]
        )

        #expect(request.id == "test-123")
        #expect(request.tool == "Bash")
        #expect(request.description == "ls -la")
        #expect(request.input["command"] == "ls -la")
    }

    @Test("ApprovalRequests are equal by id")
    func testEquality() {
        let request1 = ApprovalRequest(id: "abc", tool: "Bash", description: "cmd1")
        let request2 = ApprovalRequest(id: "abc", tool: "Edit", description: "cmd2")

        #expect(request1 == request2)
    }

    @Test("ApprovalRequests with different ids are not equal")
    func testInequality() {
        let request1 = ApprovalRequest(id: "abc", tool: "Bash", description: "cmd")
        let request2 = ApprovalRequest(id: "def", tool: "Bash", description: "cmd")

        #expect(request1 != request2)
    }
}