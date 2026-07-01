#!/usr/bin/env bash
# ===========================================================================
# Khoi dong CA HAI dich vu dub_app (nen):
#   - OmniVoice API  (:7861)  -> logs/omnivoice.log
#   - UI long tieng  (:7862)  -> logs/ui.log
#
#   ./start_all.sh
#   GRADIO_SHARE=1 ./start_all.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs
PID_DIR="$SCRIPT_DIR/.pids"
mkdir -p "$PID_DIR"

# --- OmniVoice API ---
if [ -f "$PID_DIR/omnivoice.pid" ] && kill -0 "$(cat "$PID_DIR/omnivoice.pid")" 2>/dev/null; then
    echo "[CANH BAO] OmniVoice da chay (PID $(cat "$PID_DIR/omnivoice.pid"))."
else
    echo "Khoi dong OmniVoice API..."
    nohup bash "$SCRIPT_DIR/run_omnivoice.sh" \
        > "$SCRIPT_DIR/logs/omnivoice.log" 2>&1 &
    echo $! > "$PID_DIR/omnivoice.pid"
    echo "  PID: $(cat "$PID_DIR/omnivoice.pid") | log: logs/omnivoice.log"
    echo "  Doi 'Model loaded.' trong log (~1-3 phut) truoc khi long tieng."
fi

sleep 2

# --- UI dub_app ---
if [ -f "$PID_DIR/ui.pid" ] && kill -0 "$(cat "$PID_DIR/ui.pid")" 2>/dev/null; then
    echo "[CANH BAO] UI da chay (PID $(cat "$PID_DIR/ui.pid"))."
else
    echo "Khoi dong UI dub_app..."
    UI_ENV="PYTHONUTF8=1"
    if [ "${GRADIO_SHARE:-0}" = "1" ]; then
        UI_ENV="$UI_ENV GRADIO_SHARE=1"
    fi
    # shellcheck disable=SC2086
    nohup env $UI_ENV bash "$SCRIPT_DIR/run.sh" \
        > "$SCRIPT_DIR/logs/ui.log" 2>&1 &
    echo $! > "$PID_DIR/ui.pid"
    echo "  PID: $(cat "$PID_DIR/ui.pid") | log: logs/ui.log"
fi

GRADIO_PORT="${GRADIO_PORT:-7862}"
OMNIVOICE_PORT="${OMNIVOICE_PORT:-7861}"
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '<IP-server>')"

echo ""
echo "=========================================="
echo " dub_app DA KHOI DONG (background)"
echo "=========================================="
echo " UI (PUBLIC):       http://${SERVER_IP}:${GRADIO_PORT}"
echo " OmniVoice (noi bo): http://127.0.0.1:${OMNIVOICE_PORT}"
echo ""
echo " Theo doi:"
echo "   tail -f logs/omnivoice.log"
echo "   tail -f logs/ui.log"
echo " Dung: ./stop_all.sh"
echo "=========================================="
