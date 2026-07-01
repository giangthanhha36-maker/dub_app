#!/usr/bin/env bash
# ===========================================================================
# Khoi dong CA HAI dich vu dub_app (nen) — MOT LENH:
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

GRADIO_PORT="${GRADIO_PORT:-7860}"
OMNIVOICE_PORT="${OMNIVOICE_PORT:-7861}"

mkdir -p logs
PID_DIR="$SCRIPT_DIR/.pids"
mkdir -p "$PID_DIR"

# --- Kiem tra truoc khi khoi dong ---
_preflight() {
    local ok=1

    if [ ! -f "$SCRIPT_DIR/audio.py" ]; then
        echo "[LOI] Thieu audio.py trong $SCRIPT_DIR"
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
        echo "[LOI] Khong tim thay conda. Can cho OmniVoice API."
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

_preflight

# --- OmniVoice API ---
if _is_running "$PID_DIR/omnivoice.pid"; then
    echo "[CANH BAO] OmniVoice da chay (PID $(cat "$PID_DIR/omnivoice.pid"))."
else
    echo "Khoi dong OmniVoice API (cong ${OMNIVOICE_PORT})..."
    nohup env OMNIVOICE_PORT="$OMNIVOICE_PORT" OMNIVOICE_NO_ASR="${OMNIVOICE_NO_ASR:-0}" \
        bash "$SCRIPT_DIR/run_omnivoice.sh" \
        > "$SCRIPT_DIR/logs/omnivoice.log" 2>&1 &
    echo $! > "$PID_DIR/omnivoice.pid"
    echo "  PID: $(cat "$PID_DIR/omnivoice.pid") | log: logs/omnivoice.log"
fi

sleep 3

# Kiem tra OmniVoice con song sau khi khoi dong
if ! _is_running "$PID_DIR/omnivoice.pid"; then
    echo "[LOI] OmniVoice khong khoi dong duoc. Xem logs/omnivoice.log:"
    tail -20 "$SCRIPT_DIR/logs/omnivoice.log" 2>/dev/null || true
    rm -f "$PID_DIR/omnivoice.pid"
    exit 1
fi

# --- UI dub_app ---
if _is_running "$PID_DIR/ui.pid"; then
    echo "[CANH BAO] UI da chay (PID $(cat "$PID_DIR/ui.pid"))."
else
    echo "Khoi dong UI dub_app (cong ${GRADIO_PORT})..."
    UI_ENV="PYTHONUTF8=1 GRADIO_PORT=${GRADIO_PORT}"
    if [ "${GRADIO_SHARE:-0}" = "1" ]; then
        UI_ENV="$UI_ENV GRADIO_SHARE=1"
    fi
    # shellcheck disable=SC2086
    nohup env $UI_ENV bash "$SCRIPT_DIR/run.sh" \
        > "$SCRIPT_DIR/logs/ui.log" 2>&1 &
    echo $! > "$PID_DIR/ui.pid"
    echo "  PID: $(cat "$PID_DIR/ui.pid") | log: logs/ui.log"
fi

sleep 3

if ! _is_running "$PID_DIR/ui.pid"; then
    echo "[LOI] UI khong khoi dong duoc. Xem logs/ui.log:"
    tail -20 "$SCRIPT_DIR/logs/ui.log" 2>/dev/null || true
    rm -f "$PID_DIR/ui.pid"
    exit 1
fi

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '<IP-server>')"

echo ""
echo "=========================================="
echo " dub_app DA KHOI DONG (background)"
echo "=========================================="
echo " UI (PUBLIC):        http://${SERVER_IP}:${GRADIO_PORT}"
echo " OmniVoice (noi bo):  http://127.0.0.1:${OMNIVOICE_PORT}"
echo ""
echo " QUAN TRONG: doi 'Model loaded.' trong log OmniVoice"
echo "   tail -f logs/omnivoice.log"
echo ""
echo " Theo doi UI:  tail -f logs/ui.log"
echo " Trang thai:   ./status.sh"
echo " Dung tat ca:  ./stop_all.sh"
echo "=========================================="
