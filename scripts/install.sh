#!/bin/bash
#
# Claude Approval - Installation Script
#
# This script installs the Claude Code mobile approval hooks
# and optionally starts the approval server.
#
# Usage:
#   ./install.sh           # Install hooks only
#   ./install.sh --start   # Install hooks and start server
#   ./install.sh --help    # Show help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_SOURCE="$PROJECT_DIR/.claude/hooks"
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_CONFIG_DIR/hooks"
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

# Print functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✔${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✖${NC} $1"
    exit 1
}

# Show help
show_help() {
    echo "Claude Approval - Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --start       Install hooks and start the approval server"
    echo "  --server-only Start the server without installing hooks"
    echo "  --uninstall   Remove installed hooks"
    echo "  --help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NTFY_TOPIC    Set to enable push notifications (e.g., NTFY_TOPIC=my-topic)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Install hooks only"
    echo "  $0 --start                      # Install and start server"
    echo "  NTFY_TOPIC=claude-abc $0 --start  # With push notifications"
    exit 0
}

# Check if hooks source exists
check_source() {
    if [ ! -d "$HOOKS_SOURCE" ]; then
        error "Hooks source directory not found: $HOOKS_SOURCE"
    fi

    if [ ! -f "$HOOKS_SOURCE/mobile_approval.py" ]; then
        error "mobile_approval.py not found in $HOOKS_SOURCE"
    fi

    if [ ! -f "$HOOKS_SOURCE/approval_server.py" ]; then
        error "approval_server.py not found in $HOOKS_SOURCE"
    fi
}

# Install hooks
install_hooks() {
    info "Installing Claude Approval hooks..."

    # Create Claude config directory if needed
    if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
        mkdir -p "$CLAUDE_CONFIG_DIR"
        success "Created $CLAUDE_CONFIG_DIR"
    fi

    # Create hooks directory if needed
    if [ ! -d "$HOOKS_DEST" ]; then
        mkdir -p "$HOOKS_DEST"
        success "Created $HOOKS_DEST"
    fi

    # Copy hook files
    cp "$HOOKS_SOURCE/mobile_approval.py" "$HOOKS_DEST/"
    cp "$HOOKS_SOURCE/approval_server.py" "$HOOKS_DEST/"
    chmod +x "$HOOKS_DEST/mobile_approval.py"
    chmod +x "$HOOKS_DEST/approval_server.py"
    success "Copied hook files to $HOOKS_DEST"

    # Configure settings.json
    configure_settings

    success "Hooks installed successfully!"
    echo ""
    info "Hook files installed to: $HOOKS_DEST"
    info "Settings configured in: $SETTINGS_FILE"
}

# Configure settings.json
configure_settings() {
    local hook_config='{
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
}'

    if [ -f "$SETTINGS_FILE" ]; then
        # Check if hooks are already configured
        if grep -q "PermissionRequest" "$SETTINGS_FILE" 2>/dev/null; then
            warn "settings.json already contains hook configuration"
            info "Please verify the configuration manually if needed"
            return
        fi

        # Backup existing settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
        warn "Existing settings.json backed up to $SETTINGS_FILE.backup"

        # Try to merge with existing settings using Python
        python3 << EOF
import json
import sys

try:
    with open("$SETTINGS_FILE", "r") as f:
        existing = json.load(f)
except:
    existing = {}

hook_config = {
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

# Merge configurations
if "hooks" not in existing:
    existing["hooks"] = {}
existing["hooks"]["PermissionRequest"] = hook_config["hooks"]["PermissionRequest"]

with open("$SETTINGS_FILE", "w") as f:
    json.dump(existing, f, indent=2)
EOF
        success "Updated settings.json with hook configuration"
    else
        # Create new settings file
        echo "$hook_config" > "$SETTINGS_FILE"
        success "Created settings.json with hook configuration"
    fi
}

# Uninstall hooks
uninstall_hooks() {
    info "Uninstalling Claude Approval hooks..."

    if [ -f "$HOOKS_DEST/mobile_approval.py" ]; then
        rm "$HOOKS_DEST/mobile_approval.py"
        success "Removed mobile_approval.py"
    fi

    if [ -f "$HOOKS_DEST/approval_server.py" ]; then
        rm "$HOOKS_DEST/approval_server.py"
        success "Removed approval_server.py"
    fi

    warn "Note: settings.json was not modified. Remove the PermissionRequest hook manually if needed."
    success "Uninstall complete"
}

# Start the approval server
start_server() {
    info "Starting approval server..."
    echo ""

    local server_script="$HOOKS_DEST/approval_server.py"

    if [ ! -f "$server_script" ]; then
        error "Server script not found. Run install first: $0"
    fi

    # Show ntfy status
    if [ -n "$NTFY_TOPIC" ]; then
        success "Push notifications enabled (topic: $NTFY_TOPIC)"
    else
        info "Push notifications disabled"
        info "Set NTFY_TOPIC environment variable to enable"
    fi

    echo ""

    # Start the server
    exec python3 "$server_script"
}

# Main
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --start)
            check_source
            install_hooks
            echo ""
            start_server
            ;;
        --server-only)
            start_server
            ;;
        --uninstall)
            uninstall_hooks
            ;;
        "")
            check_source
            install_hooks
            echo ""
            info "To start the server, run:"
            echo "  $0 --start"
            echo ""
            info "Or start manually with push notifications:"
            echo "  NTFY_TOPIC=your-topic python3 ~/.claude/hooks/approval_server.py"
            ;;
        *)
            error "Unknown option: $1. Use --help for usage."
            ;;
    esac
}

main "$@"