import SwiftUI
import Domain

struct ContentView: View {
    @Bindable var requests: ApprovalRequests
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionStatus

                if requests.isEmpty {
                    emptyState
                } else {
                    requestsList
                }
            }
            .navigationTitle("Claude Approval")
            .preferredColorScheme(.dark)
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Connection Status

    private var connectionStatus: some View {
        HStack {
            Circle()
                .fill(requests.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            if requests.isConnected {
                Text("Connected to \(requests.serverAddress ?? "server")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Searching for server...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.shield")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Pending Requests")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Permission requests from Claude Code\nwill appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Requests List

    private var requestsList: some View {
        List {
            ForEach(requests.requests) { request in
                RequestCard(request: request) {
                    Task {
                        await requests.approve(request)
                    }
                } onDecline: {
                    Task {
                        await requests.decline(request)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Polling

    private func startPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                await requests.refresh()
            }
        }
    }

    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Request Card

struct RequestCard: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                toolIcon
                Text(request.tool)
                    .font(.headline)
                Spacer()
                Text(request.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text(request.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Label("Decline", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private var toolIcon: some View {
        let (icon, color) = iconForTool(request.tool)
        Image(systemName: icon)
            .foregroundStyle(color)
    }

    private func iconForTool(_ tool: String) -> (String, Color) {
        switch tool {
        case "Bash":
            return ("terminal", .orange)
        case "Edit", "Write":
            return ("doc.text", .blue)
        case "Read":
            return ("eye", .green)
        default:
            return ("questionmark.circle", .gray)
        }
    }
}

#Preview {
    let requests = ApprovalRequests()
    return ContentView(requests: requests)
}