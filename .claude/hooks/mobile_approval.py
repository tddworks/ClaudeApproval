#!/usr/bin/env python3
"""
Claude Code Mobile Approval Hook (PermissionRequest)

This hook sends permission requests to the local approval server,
which relays them to an iOS app for user approval.

Output format for PermissionRequest:
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow" | "deny",
      "message": "reason for denial" (optional, for deny)
    }
  }
}
"""

import json
import sys
import urllib.request
import urllib.error
import uuid

SERVER_URL = "http://localhost:8754"
TIMEOUT = 120  # seconds


def send_request(tool: str, description: str, tool_input: dict) -> bool:
    """Send approval request to server and wait for response."""
    request_id = str(uuid.uuid4())[:8]

    payload = json.dumps({
        "id": request_id,
        "tool": tool,
        "description": description,
        "input": tool_input,
        "timeout": TIMEOUT,
    }).encode()

    req = urllib.request.Request(
        f"{SERVER_URL}/request",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT + 5) as response:
            result = json.loads(response.read())
            return result.get("approved", False)
    except urllib.error.URLError as e:
        # Server not running - fall back to allow
        print(f"Mobile approval server not reachable: {e}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return True


def output_decision(approved: bool, message: str = ""):
    """Output the decision in Claude Code's expected JSON format."""
    decision = {
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "decision": {
                "behavior": "allow" if approved else "deny"
            }
        }
    }

    if not approved and message:
        decision["hookSpecificOutput"]["decision"]["message"] = message

    print(json.dumps(decision))


def log(msg: str):
    """Log to file for debugging."""
    with open("/tmp/claude_hook.log", "a") as f:
        f.write(f"{msg}\n")


def main():
    """Main hook entry point."""
    log("Hook called!")

    try:
        # Read hook input from stdin
        raw = sys.stdin.read()
        log(f"Raw input: {raw}")
        input_data = json.loads(raw) if raw else {}
    except json.JSONDecodeError as e:
        # No valid input, allow by default
        log(f"JSON decode error: {e}")
        output_decision(True)
        sys.exit(0)

    # Extract tool info from PermissionRequest payload
    # Note: Claude Code uses "tool_name" not "tool"
    tool = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Build description based on tool type
    if tool == "Bash":
        description = tool_input.get("command", "")[:100]
    elif tool in ("Edit", "Write"):
        description = f"Modify: {tool_input.get('file_path', 'unknown file')}"
    elif tool == "Read":
        description = f"Read: {tool_input.get('file_path', 'unknown file')}"
    else:
        description = str(tool_input)[:100] if tool_input else tool

    # Send to mobile and wait for approval
    approved = send_request(tool, description, tool_input)

    # Output decision in JSON format
    if approved:
        output_decision(True)
    else:
        output_decision(False, "Denied by mobile user")

    sys.exit(0)


if __name__ == "__main__":
    main()
