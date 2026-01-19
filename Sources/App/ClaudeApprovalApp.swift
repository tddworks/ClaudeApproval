import SwiftUI
import Domain
import Infrastructure

@main
struct ClaudeApprovalApp: App {
    @State private var requests = ApprovalRequests()

    var body: some Scene {
        WindowGroup {
            ContentView(requests: requests)
                .task {
                    let service = BonjourApprovalService(requests: requests)
                    requests.configure(service: service)
                    await requests.connect()
                }
        }
    }
}