#!/usr/bin/env python3
"""
Claude Code Mobile Approval Server

A local HTTP server with Bonjour/mDNS advertising that allows
approving Claude Code permission requests from an iOS device.

Usage:
    python3 approval_server.py

    # With push notifications (using ntfy.sh):
    NTFY_TOPIC=your-secret-topic python3 approval_server.py

The server advertises itself as "_claudeapproval._tcp.local." on port 8754.
"""

import json
import os
import socket
import threading
import time
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from typing import Optional
import subprocess
import sys

# Push notification config (optional - use ntfy.sh)
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "")  # Set to enable push notifications
NTFY_SERVER = os.environ.get("NTFY_SERVER", "https://ntfy.sh")


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    """HTTP server that handles each request in a separate thread."""
    daemon_threads = True

    def handle_error(self, request, client_address):
        """Suppress connection reset errors from iOS going to background."""
        exc_type, exc_value, _ = sys.exc_info()
        if exc_type is ConnectionResetError:
            # iOS app went to background - this is expected, ignore it
            pass
        elif exc_type is BrokenPipeError:
            # Client disconnected - also expected
            pass
        else:
            # Log other errors
            print(f"⚠️  Error from {client_address}: {exc_value}")

# Server configuration
PORT = 8754
SERVICE_NAME = "ClaudeApproval"
SERVICE_TYPE = "_claudeapproval._tcp.local."

# Pending requests storage
pending_requests: dict[str, dict] = {}
request_responses: dict[str, Optional[bool]] = {}
request_events: dict[str, threading.Event] = {}
request_lock = threading.Lock()

# Notifications storage (fire-and-forget alerts)
notifications: list[dict] = []
notifications_lock = threading.Lock()


class ApprovalHandler(BaseHTTPRequestHandler):
    """HTTP request handler for approval requests."""

    def _send_json(self, data: dict, status: int = 200):
        """Send JSON response."""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _read_json(self) -> dict:
        """Read JSON from request body."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        return json.loads(body) if body else {}

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        """Handle GET requests."""
        if self.path == "/health":
            self._send_json({"status": "ok", "service": SERVICE_NAME})

        elif self.path == "/status":
            # Quick status check - are there pending messages?
            with request_lock:
                pending_count = sum(
                    1 for rid in pending_requests
                    if rid not in request_responses or request_responses[rid] is None
                )
                pending_list = [
                    {
                        "id": rid,
                        "tool": data.get("tool", "unknown"),
                        "description": data.get("description", "")[:50],
                        "age_seconds": int(time.time() - data.get("timestamp", time.time())),
                    }
                    for rid, data in pending_requests.items()
                    if rid not in request_responses or request_responses[rid] is None
                ]

            with notifications_lock:
                notification_count = len(notifications)

            self._send_json({
                "has_pending": pending_count > 0,
                "pending_count": pending_count,
                "notification_count": notification_count,
                "pending": pending_list,
            })

        elif self.path == "/pending":
            # Return all pending requests for iOS app to display
            with request_lock:
                requests = [
                    {"id": rid, **data}
                    for rid, data in pending_requests.items()
                    if rid not in request_responses or request_responses[rid] is None
                ]
            self._send_json({"requests": requests})

        elif self.path == "/notifications":
            # Return and clear notifications
            with notifications_lock:
                result = list(notifications)
                notifications.clear()
            self._send_json({"notifications": result})

        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        """Handle POST requests."""
        if self.path == "/request":
            # Hook sends permission request here
            data = self._read_json()
            request_id = data.get("id", str(time.time()))

            with request_lock:
                pending_requests[request_id] = {
                    "tool": data.get("tool", "unknown"),
                    "description": data.get("description", ""),
                    "input": data.get("input", {}),
                    "timestamp": time.time(),
                }
                request_responses[request_id] = None
                request_events[request_id] = threading.Event()

            print(f"📱 New request: {request_id} - {data.get('tool')}")

            # Send push notification (async, non-blocking)
            tool = data.get("tool", "unknown")
            desc = data.get("description", "")[:80]
            threading.Thread(
                target=send_push_notification,
                args=(f"Claude: {tool}", desc),
                daemon=True,
            ).start()

            # Wait for response (with timeout)
            timeout = data.get("timeout", 120)  # 2 minutes default
            event = request_events[request_id]
            responded = event.wait(timeout=timeout)

            with request_lock:
                response = request_responses.get(request_id)
                # Clean up
                pending_requests.pop(request_id, None)
                request_responses.pop(request_id, None)
                request_events.pop(request_id, None)

            if responded and response is not None:
                self._send_json({"approved": response})
            else:
                self._send_json({"approved": False, "timeout": True})

        elif self.path == "/respond":
            # iOS app sends approval/denial here
            data = self._read_json()
            request_id = data.get("id")
            approved = data.get("approved", False)

            with request_lock:
                if request_id in request_events:
                    request_responses[request_id] = approved
                    request_events[request_id].set()
                    action = "✅ Approved" if approved else "❌ Declined"
                    print(f"{action}: {request_id}")
                    self._send_json({"success": True})
                else:
                    self._send_json({"error": "Request not found"}, 404)

        elif self.path == "/notify":
            # Fire-and-forget notification (no response needed)
            data = self._read_json()
            notification = {
                "id": data.get("id", str(time.time())),
                "tool": data.get("tool", "Notification"),
                "description": data.get("description", ""),
                "timestamp": time.time(),
            }
            with notifications_lock:
                notifications.append(notification)
                # Keep only last 50 notifications
                if len(notifications) > 50:
                    notifications.pop(0)
            print(f"🔔 Notification: {notification['description'][:50]}")
            self._send_json({"success": True})

        else:
            self._send_json({"error": "Not found"}, 404)

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def send_push_notification(title: str, message: str, actions: list[dict] = None):
    """Send push notification via ntfy.sh (if configured)."""
    if not NTFY_TOPIC:
        return

    try:
        headers = {
            "Title": title,
            "Priority": "high",
            "Tags": "robot",
        }

        # Add action buttons if provided
        if actions:
            # Format: action=view, Open App, http://localhost:8754
            action_strs = []
            for action in actions:
                action_strs.append(f"{action['type']}, {action['label']}, {action['url']}")
            headers["Actions"] = "; ".join(action_strs)

        req = urllib.request.Request(
            f"{NTFY_SERVER}/{NTFY_TOPIC}",
            data=message.encode(),
            headers=headers,
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
        print(f"📤 Push sent: {title}")
    except Exception as e:
        print(f"⚠️  Push notification failed: {e}")


def advertise_bonjour():
    """Advertise service via Bonjour using dns-sd command."""
    try:
        # Use macOS built-in dns-sd to advertise
        process = subprocess.Popen(
            ["dns-sd", "-R", SERVICE_NAME, "_claudeapproval._tcp", "local", str(PORT)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(f"📡 Bonjour: Advertising as {SERVICE_NAME} on port {PORT}")
        return process
    except Exception as e:
        print(f"⚠️  Bonjour advertising failed: {e}")
        return None


def main():
    """Start the approval server."""
    print("=" * 50)
    print("🚀 Claude Code Mobile Approval Server")
    print("=" * 50)

    # Show push notification status
    if NTFY_TOPIC:
        print(f"📤 Push notifications: enabled (topic: {NTFY_TOPIC})")
    else:
        print("📤 Push notifications: disabled")
        print("   Set NTFY_TOPIC env var to enable (uses ntfy.sh)")

    # Start Bonjour advertising
    bonjour_process = advertise_bonjour()

    # Start HTTP server (threaded to handle concurrent requests)
    server = ThreadingHTTPServer(("0.0.0.0", PORT), ApprovalHandler)
    print(f"🌐 Server running on http://0.0.0.0:{PORT}")
    print(f"📱 Waiting for iOS app to connect...")
    print("-" * 50)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
    finally:
        if bonjour_process:
            bonjour_process.terminate()
        server.shutdown()


if __name__ == "__main__":
    main()