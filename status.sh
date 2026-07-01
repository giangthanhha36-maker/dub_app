#!/usr/bin/env bash
# ===========================================================================
# Xem trang thai dich vu dub_app.
#
#   ./status.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"

GRADIO_PORT="${GRADIO_PORT:-7860}"
OMNIVOICE_PORT="${OMNIVOICE_PORT:-7861}"

_check_pid() {
    local name="$1"
    local pid_file="$2"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "  $name: DANG CHAY (PID $(cat "$pid_file"))"
        return 0
    fi
    echo "  $name: DUNG"
    return 1
}

_check_port() {
    local port="$1"
    local label="$2"
    if command -v ss &>/dev/null && ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo "  Cong ${port} (${label}): MO"
        ss -tlnp 2>/dev/null | grep ":${port} " | head -1 | sed 's/^/    /'
        return 0
    fi
    echo "  Cong ${port} (${label}): DONG"
    return 1
}

_check_http() {
    local url="$1"
    local label="$2"
    if command -v curl &>/dev/null; then
        local code
        code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url" 2>/dev/null || echo "000")"
        if [ "$code" != "000" ] && [ "$code" != "000000" ]; then
            echo "  HTTP ${label}: OK (${code}) — ${url}"
            return 0
        fi
        echo "  HTTP ${label}: LOI — ${url}"
        return 1
    fi
}

echo "=========================================="
echo " Trang thai dub_app"
echo "=========================================="

_check_pid "OmniVoice API" "$PID_DIR/omnivoice.pid" || true
_check_pid "UI dub_app" "$PID_DIR/ui.pid" || true
echo ""
_check_port "$OMNIVOICE_PORT" "OmniVoice" || true
_check_port "$GRADIO_PORT" "UI" || true
echo ""
_check_http "http://127.0.0.1:${OMNIVOICE_PORT}" "OmniVoice" || true
_check_http "http://127.0.0.1:${GRADIO_PORT}" "UI" || true

if [ -f "$SCRIPT_DIR/logs/omnivoice.log" ]; then
    if grep -q "Model loaded" "$SCRIPT_DIR/logs/omnivoice.log" 2>/dev/null; then
        echo ""
        echo "  OmniVoice model: DA LOAD"
    else
        echo ""
        echo "  OmniVoice model: CHUA LOAD (xem: tail -f logs/omnivoice.log)"
    fi
fi

echo "=========================================="
