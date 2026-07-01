#!/usr/bin/env bash
# ===========================================================================
# Dung CA HAI dich vu dub_app (UI + OmniVoice API) — MOT LENH:
#
#   ./stop_all.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"

GRADIO_PORT="${GRADIO_PORT:-7860}"
OMNIVOICE_PORT="${OMNIVOICE_PORT:-7861}"

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

_stop_port() {
    local port="$1"
    local name="$2"
    if command -v fuser &>/dev/null && fuser "${port}/tcp" &>/dev/null; then
        echo "Giai phong cong ${port} (${name})..."
        fuser -k "${port}/tcp" 2>/dev/null || true
        sleep 1
    fi
}

echo "Dang dung dub_app..."

_stop_pid "UI" "$PID_DIR/ui.pid"
_stop_pid "OmniVoice" "$PID_DIR/omnivoice.pid"

# Fallback: tim process theo duong dan file trong repo
pkill -f "$SCRIPT_DIR/app.py" 2>/dev/null || true
pkill -f "$SCRIPT_DIR/audio.py" 2>/dev/null || true
pkill -f "$SCRIPT_DIR/run.sh" 2>/dev/null || true
pkill -f "$SCRIPT_DIR/run_omnivoice.sh" 2>/dev/null || true

# Fallback: giai phong cong
_stop_port "$GRADIO_PORT" "UI"
_stop_port "$OMNIVOICE_PORT" "OmniVoice"

echo "Da dung tat ca (UI :${GRADIO_PORT} + OmniVoice :${OMNIVOICE_PORT})."
