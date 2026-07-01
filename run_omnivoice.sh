#!/usr/bin/env bash
# ===========================================================================
# Khoi dong OmniVoice API (audio.py) — service long tieng, tach biet khoi dub_app UI.
#
#   ./run_omnivoice.sh
#   OMNIVOICE_PORT=7861 ./run_omnivoice.sh
#   OMNIVOICE_NO_ASR=1 ./run_omnivoice.sh   # nhe VRAM, khoi dong nhanh hon
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f audio.py ]; then
    echo "[LOI] Khong tim thay audio.py trong $SCRIPT_DIR"
    echo "      Copy file audio.py (service OmniVoice SRT-to-speech) vao cung thu muc."
    exit 1
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"

OMNIVOICE_PORT="${OMNIVOICE_PORT:-7861}"
OMNIVOICE_MODEL="${OMNIVOICE_MODEL:-k2-fsa/OmniVoice}"
OMNIVOICE_NO_ASR="${OMNIVOICE_NO_ASR:-0}"

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
    echo "[LOI] Khong tim thay conda."
    exit 1
fi

# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"

conda activate omnivoice 2>/dev/null || {
    echo "[LOI] Chua co moi truong 'omnivoice'."
    echo "      Chay: ./setup_omnivoice.sh"
    exit 1
}

# Kiem tra gradio import duoc (tranh loi HfFolder)
if ! python -c "import gradio" 2>/dev/null; then
    echo "[SETUP] Sua dependency omnivoice (gradio / huggingface_hub)..."
    pip install -r requirements-omnivoice.txt
fi

EXTRA_ARGS=()
if [ "$OMNIVOICE_NO_ASR" = "1" ]; then
    EXTRA_ARGS+=(--no-asr)
fi

echo "=========================================="
echo " OmniVoice API (audio.py)"
echo " GPU:  ${OMNIVOICE_CUDA_DEVICE}"
echo " Cong: ${OMNIVOICE_PORT}"
echo " Doi den khi thay: Model loaded."
echo "=========================================="

exec python audio.py \
    --model "$OMNIVOICE_MODEL" \
    --device cuda \
    --ip 0.0.0.0 \
    --port "$OMNIVOICE_PORT" \
    "${EXTRA_ARGS[@]}"
