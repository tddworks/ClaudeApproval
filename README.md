# Claude Approval

**Approve Claude Code requests from your phone** - even when you're away from your Mac.

## The Problem

You're using Claude Code to help with development, but every time it needs to run a command or edit a file, you have to be at your Mac to approve it. What if you could:

- Approve requests from your couch while your Mac runs in another room?
- Get notified on your phone when Claude needs permission?
- Let Claude work autonomously while you're making coffee?

## The Solution

Claude Approval routes permission requests to your iPhone. When Claude asks "Can I run this command?", you see it on your phone and tap Approve or Decline.

```
You're on your phone                Your Mac (running Claude Code)
        │                                      │
        │    "Can I run: npm install?"         │
        │◀─────────────────────────────────────│
        │                                      │
        │         [Approve] [Decline]          │
        │                                      │
        │──────── "Approved" ─────────────────▶│
        │                                      │
        ▼                                      ▼
```

## Setup Guide

### Step 1: Install the Hook Scripts on Your Mac

Copy the hook files to your Claude config:

```bash
# Clone the repo
git clone https://github.com/onegai/ClaudeApproval.git
cd ClaudeApproval

# Copy hooks to Claude's config directory
cp -r .claude/hooks ~/.claude/
```

### Step 2: Configure Claude Code to Use the Hook

Edit `~/.claude/settings.json` and add the hooks section:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": ".*",
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

### Step 3: Start the Approval Server

Open a terminal and run:

```bash
python3 ~/.claude/hooks/approval_server.py
```

You'll see:
```
==================================================
🚀 Claude Code Mobile Approval Server
==================================================
📤 Push notifications: disabled
   Set NTFY_TOPIC env var to enable (uses ntfy.sh)
📡 Bonjour: Advertising as ClaudeApproval on port 8754
🌐 Server running on http://0.0.0.0:8754
📱 Waiting for iOS app to connect...
--------------------------------------------------
```

### Step 4: Install the iOS App

Build and install the iOS app on your iPhone:

```bash
cd ClaudeApproval
tuist generate
open ClaudeApproval.xcworkspace
# Build and run on your iPhone (Cmd+R)
```

**Important:** Your iPhone and Mac must be on the same WiFi network.

### Step 5: Test It!

1. Open Claude Code in a new terminal
2. Ask Claude to do something that requires permission
3. Check your phone - you should see the request appear
4. Tap Approve or Decline

---

## Push Notifications (Recommended)

The iOS app must be open to receive requests via Bonjour. For background notifications, use **ntfy.sh** (free, no account needed):

### Setup Push Notifications

1. **On your iPhone:**
   - Download "ntfy" from the App Store (free)
   - Open the app and tap "+" to subscribe
   - Enter a secret topic name (e.g., `claude-myname-abc123`)
   - Keep this name private - anyone with it can send you notifications

2. **On your Mac:**
   ```bash
   # Run the server with push notifications enabled
   NTFY_TOPIC=claude-myname-abc123 python3 ~/.claude/hooks/approval_server.py
   ```

   You'll now see:
   ```
   📤 Push notifications: enabled (topic: claude-myname-abc123)
   ```

3. **Test it:**
   ```bash
   curl -d "Test notification" ntfy.sh/claude-myname-abc123
   ```
   You should receive a notification on your phone.

Now when Claude requests permission, you'll get a push notification even if the iOS app is closed!

---

## How It Works

```
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│   Claude Code   │  ──────▶ │  Local Server   │ ◀─────── │    iOS App      │
│   (your Mac)    │          │  (Python)       │          │  (your iPhone)  │
│                 │          │                 │          │                 │
│ "Run command?"  │          │  Polls for      │          │ [Approve]       │
│                 │ ◀─────── │  requests       │ ───────▶ │ [Decline]       │
└─────────────────┘          └─────────────────┘          └─────────────────┘
                                     │
                                     │ (optional)
                                     ▼
                            ┌─────────────────┐
                            │   ntfy.sh       │
                            │  Push Service   │
                            └─────────────────┘
```

1. **Claude Code** runs a command → triggers the permission hook
2. **Hook script** sends the request to the local server
3. **Server** stores the request and (optionally) sends a push notification
4. **iOS App** polls the server and displays pending requests
5. **You** tap Approve or Decline
6. **Server** sends the response back to Claude Code
7. **Claude Code** continues (or stops if declined)

---

## Troubleshooting

### "I don't see requests on my phone"

**Check 1: Is the server running?**
```bash
curl http://localhost:8754/health
# Should return: {"status": "ok", "service": "ClaudeApproval"}
```

**Check 2: Are you on the same WiFi?**
- Both your Mac and iPhone must be on the same network
- Find your Mac's IP: `ipconfig getifaddr en0`
- Try: `curl http://YOUR_MAC_IP:8754/health` from another device

**Check 3: Is the hook configured?**
- Restart Claude Code after editing `settings.json`
- Check the hook log: `cat /tmp/claude_hook.log`

### "Requests appear but I can't approve them"

The iOS app might have lost connection. The app needs to stay in the foreground for Bonjour to work reliably.

**Solution:** Enable push notifications (see above) - they work even when the app is backgrounded.

### "Push notifications aren't working"

1. Make sure you subscribed to the **exact same topic** in both:
   - The ntfy iOS app
   - The `NTFY_TOPIC` environment variable

2. Test the topic directly:
   ```bash
   curl -d "Test" ntfy.sh/your-topic-name
   ```

### "Server shows 'Connection reset by peer' errors"

This is normal - it happens when the iOS app goes to background and iOS drops the connection. The server suppresses these errors.

---

## Security Notes

- **Local Network Only**: All communication stays on your WiFi
- **No Authentication**: Assumes you trust your home/office network
- **Timeout**: Requests expire after 2 minutes (declined by default)
- **Push Topic**: Keep your ntfy topic name secret - treat it like a password

---

## File Locations

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Claude Code config with hook settings |
| `~/.claude/hooks/approval_server.py` | Server that bridges Claude and your phone |
| `~/.claude/hooks/mobile_approval.py` | Hook script called by Claude Code |
| `/tmp/claude_hook.log` | Debug log for the hook script |

---

## License

MIT