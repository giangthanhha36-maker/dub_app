#!/usr/bin/env bash
# ===========================================================================
# Tao / sua moi truong conda "omnivoice" cho audio.py (service long tieng).
#
#   chmod +x setup_omnivoice.sh
#   ./setup_omnivoice.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
    echo "[LOI] Khong tim thay conda. Cai Miniconda truoc."
    exit 1
fi

# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"

echo ">>> Tao moi truong conda 'omnivoice' (Python 3.12)..."
if conda env list | grep -qE '^omnivoice\s'; then
    echo "    Moi truong 'omnivoice' da ton tai."
else
    conda create -n omnivoice python=3.12 -y
fi

conda activate omnivoice

echo ">>> Nang cap pip..."
pip install --no-cache-dir -U "pip>=24.0"

echo ">>> Cai torch GPU (cu128)..."
pip install --no-cache-dir torch==2.8.0+cu128 torchaudio==2.8.0+cu128 torchvision==0.23.0+cu128 \
    --extra-index-url https://download.pytorch.org/whl/cu128

echo ">>> Cai gradio stack (truoc omnivoice — tranh backtracking)..."
pip install --no-cache-dir -r requirements-omnivoice-base.txt

echo ">>> Cai omnivoice + thu vien audio..."
pip install --no-cache-dir -r requirements-omnivoice.txt

python -c "import gradio; import huggingface_hub; print('[OK] gradio', gradio.__version__, '| huggingface_hub', huggingface_hub.__version__)"
python -c "import torch; print('[OK] torch', torch.__version__, 'cuda', torch.cuda.is_available())"

conda deactivate

echo ""
echo "=========================================="
echo " OMNIVOICE ENV XONG"
echo "=========================================="
echo " Khoi dong API:"
echo "   ./run_omnivoice.sh"
echo "=========================================="
