# Claude Approval

A proof-of-concept iOS app that enables mobile approval of Claude Code permission requests via local network (Bonjour).

## Overview

When Claude Code needs permission to execute commands or edit files, this system routes the request to your iPhone for approval instead of requiring interaction on your Mac.

```
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│   Claude Code   │  ──────▶ │  Local Server   │ ◀─────── │    iOS App      │
│   (Mac)         │          │  (Python)       │          │    (iPhone)     │
│                 │          │                 │          │                 │
│ "Run ls -la?"   │          │  Bonjour        │          │ [Approve]       │
│                 │ ◀─────── │  Advertised     │ ───────▶ │ [Decline]       │
└─────────────────┘          └─────────────────┘          └─────────────────┘
         WiFi Network (Same Network Required)
```

## Features

- **Zero Configuration**: Bonjour auto-discovery finds the server
- **Local Only**: All communication stays on your local network
- **Simple UI**: Two buttons - Approve or Decline
- **Real-time**: Requests appear instantly on your phone

## Quick Start

### 1. Start the Server (Mac)

```bash
python3 ~/.claude/hooks/approval_server.py
```

You should see:
```
==================================================
🚀 Claude Code Mobile Approval Server
==================================================
📡 Bonjour: Advertising as ClaudeApproval on port 8754
🌐 Server running on http://0.0.0.0:8754
📱 Waiting for iOS app to connect...
--------------------------------------------------
```

### 2. Install the iOS App

```bash
cd /path/to/ClaudeApproval
tuist generate
open ClaudeApproval.xcworkspace
```

Build and run on your iPhone (must be on the same WiFi network).

### 3. Enable the Hook

The hook is configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /Users/YOUR_USERNAME/.claude/hooks/mobile_approval.py"
          }
        ]
      }
    ]
  }
}
```

### 4. Use Claude Code

When Claude needs permission, the request appears on your phone. Tap to approve or decline.

## Project Structure

```
ClaudeApproval/
├── Project.swift              # Tuist configuration
├── Sources/
│   ├── Domain/                # Pure business logic
│   │   ├── Models/
│   │   │   ├── ApprovalRequest.swift
│   │   │   └── ApprovalRequests.swift
│   │   └── Protocols/
│   │       └── ApprovalService.swift
│   ├── Infrastructure/        # Network implementation
│   │   └── BonjourApprovalService.swift
│   └── App/                   # SwiftUI views
│       ├── ClaudeApprovalApp.swift
│       ├── ContentView.swift
│       └── Resources/
└── Tests/
    └── DomainTests/
```

## Design Guidelines

### Architecture Principles

1. **Layered Architecture**: Domain → Infrastructure → App
   - Domain has zero external dependencies
   - Infrastructure implements Domain protocols
   - App depends on both layers

2. **Rich Domain Model**: Entities contain behavior, not just data
   - `ApprovalRequest` is an `@Observable` entity
   - `ApprovalRequests` is a root aggregate managing state

3. **Protocol-Based Abstraction**: Infrastructure details hidden behind protocols
   - `ApprovalService` protocol defines the contract
   - `BonjourApprovalService` is the concrete implementation

### UI/UX Guidelines

1. **Dark Mode**: Forced dark theme for consistency
2. **Minimal UI**: Focus on the two primary actions
3. **Status Visibility**: Connection state always visible
4. **Tool Icons**: Visual differentiation by tool type

### Request Card Design

```
┌─────────────────────────────────────┐
│ 🖥️ Bash                    2s ago   │
│                                     │
│ ls -la /Users/...                   │
│                                     │
│ ┌─────────────┐ ┌─────────────────┐ │
│ │   Decline   │ │     Approve     │ │
│ │    (red)    │ │    (green)      │ │
│ └─────────────┘ └─────────────────┘ │
└─────────────────────────────────────┘
```

### Color Palette

| Element | Color |
|---------|-------|
| Approve Button | Green (`Color.green`) |
| Decline Button | Red (`Color.red`) |
| Connected Status | Green dot |
| Disconnected Status | Red dot |
| Bash Tool | Orange |
| Edit/Write Tool | Blue |
| Read Tool | Green |

## Security Considerations

- **Local Network Only**: No internet exposure
- **No Authentication**: Assumes trusted home/office network
- **Timeout**: Requests expire after 120 seconds
- **Fallback**: If server unreachable, operations are allowed (configurable)

## Future Enhancements

- [ ] Push notifications when requests arrive
- [ ] Request history/audit log
- [ ] Biometric authentication (Face ID/Touch ID)
- [ ] Multiple Mac support
- [ ] Request details expansion
- [ ] Sound/haptic feedback

## Troubleshooting

### iOS App Shows "Searching for server..."

1. Ensure Mac and iPhone are on the same WiFi network
2. Check server is running: `curl http://YOUR_MAC_IP:8754/health`
3. Check firewall allows port 8754

### Requests Not Appearing

1. Verify hook is configured in `~/.claude/settings.json`
2. Check server logs for incoming requests
3. Ensure `matcher` includes the tool type (Bash, Edit, Write)

### Server Won't Start

```bash
# Check if port is in use
lsof -i :8754

# Kill existing process if needed
kill -9 <PID>
```

## License

MIT
