#!/usr/bin/env bash
# ===========================================================================
# Khoi dong UI long tieng doc lap (dub_app).
#
#   ./run.sh
#   GRADIO_PORT=7862 ./run.sh
#   GRADIO_SHARE=1 ./run.sh
#
# Can OmniVoice dang chay: ../start_omnivoice.sh (cong 7861)
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f config.yaml ]; then
    cp config-template.yaml config.yaml
    echo "[OK] Da tao config.yaml tu template."
fi

# Kich hoat conda (tu dong tim duong dan pho bien)
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
    conda activate ste 2>/dev/null || true
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"
export GRADIO_PORT="${GRADIO_PORT:-7862}"

echo "=========================================="
echo " dub_app — Long tieng video"
echo " Cong: ${GRADIO_PORT}"
echo " OmniVoice can chay tai URL trong config.yaml"
echo "=========================================="

exec python app.py
