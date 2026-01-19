import Foundation
import Network
import Domain

/// Implementation of ApprovalService using Bonjour/mDNS for server discovery
@MainActor
public final class BonjourApprovalService: ApprovalService, @unchecked Sendable {
    private let serviceType = "_claudeapproval._tcp"
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var serverEndpoint: NWEndpoint?
    private var serverHost: String?
    private var serverPort: UInt16 = 8754

    private weak var requests: ApprovalRequests?

    public init(requests: ApprovalRequests) {
        self.requests = requests
    }

    // MARK: - ApprovalService

    public func startBrowsing() async {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: "local."), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("Browser ready")
                case .failed(let error):
                    print("Browser failed: \(error)")
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                guard let self else { return }
                for result in results {
                    if case .service(let name, let type, let domain, _) = result.endpoint {
                        print("Found service: \(name).\(type)\(domain)")
                        await self.resolveAndConnect(endpoint: result.endpoint)
                        break
                    }
                }
            }
        }

        browser?.start(queue: .main)
    }

    public func stopBrowsing() async {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        requests?.updateConnectionStatus(connected: false, address: nil)
    }

    public func fetchPendingRequests() async throws -> [ApprovalRequest] {
        guard let serverHost else {
            throw ApprovalError.notConnected
        }

        let url = URL(string: "http://\(serverHost):\(serverPort)/pending")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let response = try JSONDecoder().decode(PendingResponse.self, from: data)
        return response.requests.map { dto in
            ApprovalRequest(
                id: dto.id,
                tool: dto.tool,
                description: dto.description,
                input: dto.input ?? [:],
                timestamp: Date(timeIntervalSince1970: dto.timestamp)
            )
        }
    }

    public func respond(to requestId: String, approved: Bool) async throws {
        guard let serverHost else {
            throw ApprovalError.notConnected
        }

        let url = URL(string: "http://\(serverHost):\(serverPort)/respond")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RespondRequest(id: requestId, approved: approved)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApprovalError.requestFailed
        }
    }

    // MARK: - Private

    private func resolveAndConnect(endpoint: NWEndpoint) async {
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostString: String
                        switch host {
                        case .ipv4(let addr):
                            hostString = self.ipv4String(from: addr)
                        case .ipv6(let addr):
                            hostString = self.ipv6String(from: addr)
                        case .name(let name, _):
                            hostString = name
                        @unknown default:
                            hostString = "localhost"
                        }
                        self.serverHost = hostString
                        self.serverPort = port.rawValue
                        self.requests?.updateConnectionStatus(connected: true, address: "\(hostString):\(port.rawValue)")
                        print("Connected to server at \(hostString):\(port.rawValue)")
                    }
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self.requests?.updateConnectionStatus(connected: false, address: nil)
                default:
                    break
                }
            }
        }

        self.connection = connection
        connection.start(queue: .main)
    }

    private func ipv4String(from addr: IPv4Address) -> String {
        let data = addr.rawValue
        return "\(data[0]).\(data[1]).\(data[2]).\(data[3])"
    }

    private func ipv6String(from addr: IPv6Address) -> String {
        // Simplified - just use description or fallback
        return "localhost"
    }
}

// MARK: - DTOs

private struct PendingResponse: Codable {
    let requests: [RequestDTO]
}

private struct RequestDTO: Codable {
    let id: String
    let tool: String
    let description: String
    let input: [String: String]?
    let timestamp: Double
}

private struct RespondRequest: Codable {
    let id: String
    let approved: Bool
}

// MARK: - Errors

public enum ApprovalError: Error {
    case notConnected
    case requestFailed
}