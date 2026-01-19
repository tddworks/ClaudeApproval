import SwiftUI
import Domain
import Infrastructure
import UserNotifications

@main
struct ClaudeApprovalApp: App {
    @State private var requests = ApprovalRequests()
    @State private var service: BonjourApprovalService?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(requests: requests)
                .task {
                    await setupNotifications()
                    await connectService()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
    }

    private func setupNotifications() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("Notifications permission: \(granted ? "granted" : "denied")")
        } catch {
            print("Notifications error: \(error)")
        }
    }

    private func connectService() async {
        let newService = BonjourApprovalService(requests: requests)
        service = newService
        requests.configure(service: newService)
        await requests.connect()
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App came to foreground - reconnect if needed
            print("App became active - checking connection")
            Task {
                if !requests.isConnected {
                    print("Reconnecting...")
                    await requests.connect()
                }
                // Always refresh when becoming active
                await requests.refresh()
            }

        case .inactive:
            // App is transitioning (e.g., switching apps)
            print("App became inactive")

        case .background:
            // App went to background
            print("App went to background")
            // Schedule background refresh if needed
            scheduleBackgroundRefresh()

        @unknown default:
            break
        }
    }

    private func scheduleBackgroundRefresh() {
        // Background App Refresh is handled by the system
        // This is a placeholder for future enhancement
        print("Background mode - polling will stop")
    }
}
