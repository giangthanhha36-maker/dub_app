#!/usr/bin/env bash
# ===========================================================================
# Khoi dong UI long tieng doc lap (dub_app).
#
#   ./run.sh
#   GRADIO_PORT=7860 ./run.sh
#   GRADIO_SHARE=1 ./run.sh
#
# Yeu cau: OmniVoice API dang chay (audio.py, cong 7861) — URL trong config.yaml
# Luu y: dub_app dung venv RIENG (.venv/), KHONG chay trong env omnivoice.
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f config.yaml ]; then
    cp config-template.yaml config.yaml
    echo "[OK] Da tao config.yaml tu template."
fi

VENV_DIR="$SCRIPT_DIR/.venv"

# Canh bao neu dang o env omnivoice (xung dot gradio / huggingface_hub)
if [ "${CONDA_DEFAULT_ENV:-}" = "omnivoice" ]; then
    echo "[CANH BAO] Ban dang trong env 'omnivoice'."
    echo "           dub_app se dung .venv/ rieng — KHONG dung Python cua omnivoice."
    echo ""
fi

# Uu tien Python 3.10–3.12 (Gradio 4.44 on dinh hon Python 3.13)
_pick_python() {
    for cmd in python3.12 python3.11 python3.10 python3; do
        if command -v "$cmd" &>/dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    echo "[LOI] Khong tim thay python3." >&2
    exit 1
}

PYTHON_BIN="$(_pick_python)"

# Tao venv rieng cho dub_app (nhe, tach biet khoi OmniVoice GPU)
if [ ! -d "$VENV_DIR" ]; then
    echo "[SETUP] Tao moi truong .venv (dung ${PYTHON_BIN})..."
    "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Cai / sua thu vien neu import gradio that bai (vd. thieu pyaudioop tren Py 3.13)
if ! python -c "import gradio" 2>/dev/null; then
    echo "[SETUP] Cai/cap nhat requirements.txt vao .venv..."
    pip install -r requirements.txt
fi

# Python 3.13: dam bao co pyaudioop (audioop da bi xoa khoi stdlib)
PY_MINOR="$(python -c "import sys; print(sys.version_info.minor)")"
if [ "$PY_MINOR" -ge 13 ] && ! python -c "import pyaudioop" 2>/dev/null; then
    echo "[SETUP] Python 3.13 — cai pyaudioop..."
    pip install "pyaudioop>=0.3.0"
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"
export GRADIO_PORT="${GRADIO_PORT:-7860}"

echo "=========================================="
echo " dub_app — Long tieng video"
echo " Python: $(which python) ($(python --version))"
echo " Cong:   ${GRADIO_PORT}"
echo " OmniVoice API: xem tts.server_url trong config.yaml"
echo "=========================================="

exec python app.py
