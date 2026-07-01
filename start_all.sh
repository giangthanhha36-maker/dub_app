#!/usr/bin/env bash
# ===========================================================================
# Khoi dong dub_app (nen) — MOT LENH, MOT PROCESS:
#
#   ./start_all.sh
#   GRADIO_SHARE=1 ./start_all.sh
#   OMNIVOICE_NO_ASR=1 ./start_all.sh
#
# Dung: ./stop_all.sh
# Xem trang thai: ./status.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GRADIO_PORT="${GRADIO_PORT:-8000}"

mkdir -p logs
PID_DIR="$SCRIPT_DIR/.pids"
mkdir -p "$PID_DIR"

_preflight() {
    local ok=1

    if [ ! -f "$SCRIPT_DIR/app.py" ]; then
        echo "[LOI] Thieu app.py trong $SCRIPT_DIR"
        ok=0
    fi

    if ! command -v conda &>/dev/null; then
        for _conda_sh in \
            "$HOME/miniconda3/etc/profile.d/conda.sh" \
            "$HOME/anaconda3/etc/profile.d/conda.sh" \
            "/opt/conda/etc/profile.d/conda.sh"
        do
            if [ -f "$_conda_sh" ]; then
                # shellcheck source=/dev/null
                source "$_conda_sh"
                break
            fi
        done
        unset _conda_sh
    fi

    if command -v conda &>/dev/null; then
        # shellcheck disable=SC1091
        source "$(conda info --base)/etc/profile.d/conda.sh"
        if ! conda env list | grep -qE '^omnivoice\s'; then
            echo "[LOI] Chua co env conda 'omnivoice'. Chay: ./setup_omnivoice.sh"
            ok=0
        fi
    else
        echo "[LOI] Khong tim thay conda."
        ok=0
    fi

    if ! command -v ffmpeg &>/dev/null; then
        echo "[CANH BAO] Khong tim thay ffmpeg trong PATH."
    fi

    if [ ! -f "$SCRIPT_DIR/config.yaml" ]; then
        cp "$SCRIPT_DIR/config-template.yaml" "$SCRIPT_DIR/config.yaml"
        echo "[OK] Da tao config.yaml tu template."
    fi

    if [ "$ok" -eq 0 ]; then
        exit 1
    fi
}

_is_running() {
    local pid_file="$1"
    [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

# shellcheck source=scripts/port_utils.sh
source "$SCRIPT_DIR/scripts/port_utils.sh"

_preflight

# Xoa PID cu cua OmniVoice API (da gop vao app.py)
rm -f "$PID_DIR/omnivoice.pid"

if _is_running "$PID_DIR/ui.pid"; then
    echo "[CANH BAO] dub_app da chay (PID $(cat "$PID_DIR/ui.pid"))."
    echo "           UI: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${GRADIO_PORT}"
    exit 0
fi

if port_in_use "$GRADIO_PORT"; then
    ensure_port_free "$GRADIO_PORT" "$SCRIPT_DIR" || exit 1
fi

echo "Khoi dong dub_app (cong ${GRADIO_PORT})..."
UI_ENV="PYTHONUTF8=1 GRADIO_PORT=${GRADIO_PORT} GRADIO_SERVER_PORT=${GRADIO_PORT} OMNIVOICE_NO_ASR=${OMNIVOICE_NO_ASR:-0}"
if [ "${GRADIO_SHARE:-0}" = "1" ]; then
    UI_ENV="$UI_ENV GRADIO_SHARE=1"
fi
# shellcheck disable=SC2086
nohup env $UI_ENV bash "$SCRIPT_DIR/run.sh" \
    > "$SCRIPT_DIR/logs/ui.log" 2>&1 &
echo $! > "$PID_DIR/ui.pid"
echo "  PID: $(cat "$PID_DIR/ui.pid") | log: logs/ui.log"

sleep 3

if ! _is_running "$PID_DIR/ui.pid"; then
    echo "[LOI] dub_app khong khoi dong duoc. Xem logs/ui.log:"
    tail -20 "$SCRIPT_DIR/logs/ui.log" 2>/dev/null || true
    rm -f "$PID_DIR/ui.pid"
    exit 1
fi

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '<IP-server>')"

echo ""
echo "=========================================="
echo " dub_app DA KHOI DONG (background)"
echo "=========================================="
echo " UI (PUBLIC): http://${SERVER_IP}:${GRADIO_PORT}"
echo ""
echo " QUAN TRONG: doi 'Model loaded.' trong log"
echo "   tail -f logs/ui.log"
echo ""
echo " Trang thai:  ./status.sh"
echo " Dung tat ca: ./stop_all.sh"
echo "=========================================="
