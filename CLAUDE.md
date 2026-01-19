# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project (required before building)
tuist generate

# Build the project
tuist build

# Run tests
tuist test

# Open in Xcode
open ClaudeApproval.xcworkspace
```

## Architecture

This iOS app uses a **layered architecture** with three modules:

```
App (SwiftUI views) → Infrastructure (Network/Bonjour) → Domain (pure Swift)
```

### Layer Dependencies

- **Domain** (`Sources/Domain/`): Pure business logic with no external dependencies. Contains:
  - `ApprovalRequest` - `@Observable` entity representing a permission request
  - `ApprovalRequests` - Root aggregate managing request collection and connection state
  - `ApprovalService` - Protocol for server communication

- **Infrastructure** (`Sources/Infrastructure/`): Implements Domain protocols using Network framework.
  - `BonjourApprovalService` - Discovers servers via Bonjour, communicates via HTTP

- **App** (`Sources/App/`): SwiftUI views and app entry point.
  - `ContentView` - Main UI with connection status and request cards
  - `RequestCard` - Individual approval request with Approve/Decline buttons

### Rich Domain Model Pattern

Following DDD principles:

- **Entity** (`ApprovalRequest`): `@Observable` class with identity (String ID)
- **Root Aggregate** (`ApprovalRequests`): Manages collection, connection state, and service orchestration
- **Repository/Service Injection**: Aggregate receives service via `configure()` method

## System Components

### 1. Approval Server (Python)
Location: `~/.claude/hooks/approval_server.py`

- HTTP server on port 8754
- Bonjour advertising as `_claudeapproval._tcp.local.`
- Endpoints:
  - `GET /health` - Health check
  - `GET /pending` - List pending requests
  - `POST /request` - Hook submits request (blocks until response)
  - `POST /respond` - iOS app approves/declines

### 2. Hook Script (Python)
Location: `~/.claude/hooks/mobile_approval.py`

- Intercepts `PermissionRequest` events for Bash/Edit/Write tools
- Sends request details to server
- Waits for mobile response (120s timeout)
- Exit codes: 0 = allow, 2 = deny

### 3. iOS App
- Discovers server via Bonjour (`NWBrowser`)
- Polls `/pending` every 2 seconds
- Sends approval/decline via `/respond`

## Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐
│ Claude Code │────▶│ Hook Script  │────▶│   Server    │◀────│ iOS App  │
│             │     │              │     │  (Python)   │     │          │
│ Permission  │     │ POST /request│     │             │     │ Bonjour  │
│ Request     │     │ (blocking)   │     │ Holds conn  │     │ Discovery│
│             │     │              │     │ until resp  │     │          │
│             │◀────│ Exit 0 or 2  │◀────│             │◀────│ Approve/ │
│             │     │              │     │             │     │ Decline  │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────┘
```

## Configuration

### Claude Code Hooks (`~/.claude/settings.json`)
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/mobile_approval.py"
          }
        ]
      }
    ]
  }
}
```

### iOS Info.plist Requirements
- `NSLocalNetworkUsageDescription` - Explains local network access
- `NSBonjourServices` - Lists `_claudeapproval._tcp` for discovery

## Tech Stack

- Swift 6.0 with complete concurrency checking
- iOS 18.0+ deployment target
- Tuist for project generation
- Network framework for Bonjour discovery
- Dark mode UI (forced via `.preferredColorScheme(.dark)`)

## Testing

```bash
# 1. Start the server
python3 ~/.claude/hooks/approval_server.py

# 2. Test server health
curl http://localhost:8754/health

# 3. Simulate a request (in another terminal)
curl -X POST http://localhost:8754/request \
  -H "Content-Type: application/json" \
  -d '{"id":"test-1","tool":"Bash","description":"ls -la","timeout":30}'

# 4. Approve via curl (in another terminal, within 30s)
curl -X POST http://localhost:8754/respond \
  -H "Content-Type: application/json" \
  -d '{"id":"test-1","approved":true}'
```
