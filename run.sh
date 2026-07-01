#!/usr/bin/env bash
# ===========================================================================
# Khoi dong dub_app — UI + OmniVoice trong CUNG mot process.
#
#   ./run.sh
#   GRADIO_PORT=7860 ./run.sh
#   GRADIO_SHARE=1 ./run.sh
#   OMNIVOICE_NO_ASR=1 ./run.sh   # nhe VRAM
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f config.yaml ]; then
    cp config-template.yaml config.yaml
    echo "[OK] Da tao config.yaml tu template."
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"
export GRADIO_PORT="${GRADIO_PORT:-7860}"
OMNIVOICE_NO_ASR="${OMNIVOICE_NO_ASR:-0}"
export OMNIVOICE_NO_ASR

if [ -z "${OMNIVOICE_CUDA_DEVICE:-}" ] && command -v nvidia-smi &>/dev/null; then
    _GPU_COUNT="$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${_GPU_COUNT:-0}" -ge 2 ]; then
        OMNIVOICE_CUDA_DEVICE=1
        echo "[INFO] Phat hien ${_GPU_COUNT} GPU -> OmniVoice dung GPU ${OMNIVOICE_CUDA_DEVICE}"
    else
        OMNIVOICE_CUDA_DEVICE=0
    fi
fi
OMNIVOICE_CUDA_DEVICE="${OMNIVOICE_CUDA_DEVICE:-0}"
export CUDA_VISIBLE_DEVICES="${OMNIVOICE_CUDA_DEVICE}"

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

if ! command -v conda &>/dev/null; then
    echo "[LOI] Khong tim thay conda. Chay: ./setup_omnivoice.sh"
    exit 1
fi

# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"

conda activate omnivoice 2>/dev/null || {
    echo "[LOI] Chua co moi truong 'omnivoice'."
    echo "      Chay: ./setup_omnivoice.sh"
    exit 1
}

# Cai / cap nhat deps neu thieu
if ! python -c "import gradio, omnivoice, yaml, soundfile" 2>/dev/null; then
    echo "[SETUP] Cai dependency dub_app..."
    pip install -r requirements-omnivoice-base.txt
    pip install -r requirements-omnivoice.txt
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "[CANH BAO] Khong tim thay ffmpeg trong PATH."
fi

echo "=========================================="
echo " dub_app — Long tieng video (1 process)"
echo " Python: $(which python) ($(python --version))"
echo " GPU:    ${OMNIVOICE_CUDA_DEVICE}"
echo " Cong:   ${GRADIO_PORT}"
echo " Doi den khi thay: Model loaded."
echo "=========================================="

exec python app.py
