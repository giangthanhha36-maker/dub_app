#!/usr/bin/env bash
# ===========================================================================
# Dung CA HAI dich vu dub_app (UI + OmniVoice API).
#
#   ./stop_all.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"

_stop_pid() {
    local name="$1"
    local pid_file="$2"
    if [ -f "$pid_file" ]; then
        local pid
        pid="$(cat "$pid_file")"
        if kill -0 "$pid" 2>/dev/null; then
            echo "Dung $name (PID $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    fi
}

_stop_pid "UI" "$PID_DIR/ui.pid"
_stop_pid "OmniVoice" "$PID_DIR/omnivoice.pid"

# Fallback: tim process theo ten file trong thu muc nay
pkill -f "$SCRIPT_DIR/app.py" 2>/dev/null || true
pkill -f "$SCRIPT_DIR/audio.py" 2>/dev/null || true

echo "Da dung dub_app (UI + OmniVoice)."
