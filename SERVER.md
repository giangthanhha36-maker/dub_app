# Trien khai dub_app tren Linux server (headless)

Huong dan cho server Linux **khong co man hinh**, thao tac qua SSH. Giao dien web truy cap tu trinh duyet may ca nhan.

---

## 1. Tong quan cong

| Cong | Dich vu | Mo ra internet? |
|------|---------|-----------------|
| **7860** | dub_app (`app.py` — UI + OmniVoice) | **CO** — cong ban truy cap |

```text
http://<IP-server>:7860
```

OmniVoice chay **trong cung process** voi UI — khong can mo cong 7861.

---

## 2. Yeu cau he thong

- Ubuntu 20.04 / 22.04 / 24.04 (hoac Linux tuong duong)
- GPU NVIDIA + driver (`nvidia-smi` chay duoc)
- RAM khuyen nghi >= 16 GB, VRAM >= 12 GB
- O dia trong >= 30 GB (model AI + video tam)
- `git`, `ffmpeg`, Miniconda

```bash
sudo apt update
sudo apt install -y git ffmpeg wget
```

Cai Miniconda (neu chua co):

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
```

---

## 3. Cai dat

```bash
git clone <repo-dub_app>
cd dub_app

chmod +x setup_omnivoice.sh run.sh start_all.sh stop_all.sh status.sh
cp config-template.yaml config.yaml

./setup_omnivoice.sh
```

Lan dau `setup_omnivoice.sh` tai torch + model OmniVoice — mat vai phut.

---

## 4. Khoi dong dich vu

### Cach A — Mot lenh (khuyen nghi)

```bash
./start_all.sh
./status.sh
tail -f logs/ui.log   # doi dong "Model loaded."
```

Dung tat ca:

```bash
./stop_all.sh
```

### Cach B — Foreground / tmux

```bash
tmux new -s dub
./run.sh
# Ctrl+B roi D de detach
# Quay lai: tmux attach -t dub
```

### CLI headless (khong can UI)

```bash
conda activate omnivoice
python -m pipeline.cli --video input.mp4 --srt input.srt
```

---

## 5. Truy cap tu may ca nhan

### Mo firewall cong 7860

```bash
sudo ufw allow 7860/tcp
```

Tren VPS (AWS, GCP, RunPod…): mo **TCP 7860** trong Security Group.

### SSH tunnel (khong can mo cong public)

Tren may ca nhan:

```bash
ssh -L 7860:localhost:7860 user@<IP-server>
```

Mo trinh duyet: `http://localhost:7860`

### Link Gradio public

```bash
GRADIO_SHARE=1 ./run.sh
```

Link dang `https://xxxxx.gradio.live` trong log.

---

## 6. Doi cong UI

```bash
./stop_all.sh
GRADIO_PORT=8080 ./run.sh
```

Hoac sua `config.yaml` → `ui.port: 8080`.

---

## 7. Moi truong Python

| Thanh phan | Env | Lenh |
|------------|-----|------|
| dub_app (UI + TTS) | `conda activate omnivoice` | `./run.sh` |

Khong con `.venv` rieng hay service API tren cong 7861.

---

## 8. Xu ly su co thuong gap

| Trieu chung | Cach xu ly |
|-------------|------------|
| `HfFolder` / `huggingface_hub` | Trong env omnivoice: `pip install -r requirements-omnivoice-base.txt` hoac chay lai `./setup_omnivoice.sh` |
| `Cannot find empty port 7860` | Process cu chua tat: `./stop_all.sh` hoac `fuser -k 7860/tcp` |
| Out of memory GPU | `OMNIVOICE_NO_ASR=1 ./run.sh` hoac `no_asr: true` trong config.yaml |
| Model load cham | Binh thuong — doi "Model loaded." trong `logs/ui.log` |

---

## 9. Lenh nhanh

```bash
# Cai lan dau
./setup_omnivoice.sh

# Chay
./start_all.sh
./status.sh

# Truy cap
# http://<IP-server>:7860

# Dung
./stop_all.sh
```
