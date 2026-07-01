#!/usr/bin/env bash
# ===========================================================================
# Khoi dong UI long tieng doc lap (dub_app).
#
#   ./run.sh
#   GRADIO_PORT=7862 ./run.sh
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

# Tao venv rieng cho dub_app (nhe, tach biet khoi OmniVoice GPU)
if [ ! -d "$VENV_DIR" ]; then
    echo "[SETUP] Tao moi truong .venv cho dub_app..."
    python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Cai / cap nhat thu vien neu chua co gradio
if ! python -c "import gradio" 2>/dev/null; then
    echo "[SETUP] Cai requirements.txt vao .venv..."
    pip install -r requirements.txt
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"
export GRADIO_PORT="${GRADIO_PORT:-7862}"

echo "=========================================="
echo " dub_app — Long tieng video"
echo " Python: $(which python)"
echo " Cong:   ${GRADIO_PORT}"
echo " OmniVoice API: xem tts.server_url trong config.yaml"
echo "=========================================="

exec python app.py
