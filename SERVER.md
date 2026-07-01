# Trien khai dub_app tren Linux server (headless)

Huong dan cho server Linux **khong co man hinh**, thao tac qua SSH. Giao dien web truy cap tu trinh duyet may ca nhan.

---

## 1. Tong quan cong

| Cong | Dich vu | Mo ra internet? |
|------|---------|-----------------|
| **7862** | dub_app UI (`app.py`) | **CO** — cong ban truy cap |
| **7861** | OmniVoice API (`audio.py`) | **KHONG** (mac dinh chi localhost) |

```text
http://<IP-server>:7862
```

Cung may: `tts.server_url: "http://127.0.0.1:7861"` trong `config.yaml`.

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

chmod +x setup_omnivoice.sh run_omnivoice.sh run.sh start_all.sh stop_all.sh
cp config-template.yaml config.yaml

./setup_omnivoice.sh
```

Lan dau `setup_omnivoice.sh` tai torch + model OmniVoice — mat vai phut.

---

## 4. Khoi dong dich vu

### Cach A — Mot lenh (nen)

```bash
./start_all.sh
tail -f logs/omnivoice.log   # doi dong "Model loaded."
tail -f logs/ui.log
```

### Cach B — Hai terminal / tmux

```bash
# Phien 1
./run_omnivoice.sh

# Phien 2 (sau khi Model loaded.)
./run.sh
```

### tmux (giu chay sau khi thoat SSH)

```bash
tmux new -s dub
./start_all.sh
# Ctrl+B roi D de detach
# Quay lai: tmux attach -t dub
```

Dung:

```bash
./stop_all.sh
```

---

## 5. Truy cap tu may ca nhan

### Mo firewall cong 7862

```bash
sudo ufw allow 7862/tcp
```

Tren VPS (AWS, GCP, RunPod…): mo **TCP 7862** trong Security Group.

### SSH tunnel (khong can mo cong public)

Tren may ca nhan:

```bash
ssh -L 7862:localhost:7862 user@<IP-server>
```

Mo trinh duyet: `http://localhost:7862`

### Link Gradio public

```bash
GRADIO_SHARE=1 ./run.sh
```

Link dang `https://xxxxx.gradio.live` trong log.

---

## 6. Doi cong UI

```bash
# Dung process cu truoc
./stop_all.sh
# hoac: fuser -k 7862/tcp

GRADIO_PORT=8080 ./run.sh
```

Hoac sua `config.yaml` → `ui.port: 8080`.

---

## 7. Hai moi truong Python (quan trong)

| Thanh phan | Env | Lenh |
|------------|-----|------|
| UI dub_app | `.venv/` (tu dong) | `./run.sh` |
| OmniVoice API | `conda activate omnivoice` | `./run_omnivoice.sh` |

**Khong** chay `./run.sh` trong env `omnivoice` — se loi `HfFolder` / xung dot Gradio.

---

## 8. Xu ly su co thuong gap

| Trieu chung | Cach xu ly |
|-------------|------------|
| `HfFolder` / `huggingface_hub` | Trong env omnivoice: `pip install -r requirements-omnivoice.txt` hoac chay lai `./setup_omnivoice.sh` |
| `audioop` / `pyaudioop` (Python 3.13) | `./run.sh` tu cai; hoac `rm -rf .venv` roi chay lai (uu tien python3.12) |
| `Cannot find empty port 7862` | Process cu chua tat: `fuser -k 7862/tcp` hoac `./stop_all.sh` |
| `Connection refused` :7861 | OmniVoice chua chay: `./run_omnivoice.sh`, doi `Model loaded.` |
| Khong vao duoc `:7862` tu ngoai | Kiem tra `ufw` + Security Group VPS; thu SSH tunnel |
| Out of memory GPU | `OMNIVOICE_NO_ASR=1 ./run_omnivoice.sh` (nhe VRAM hon) |

Kiem tra OmniVoice san sang:

```bash
curl http://127.0.0.1:7861
```

---

## 9. Lenh nhanh

```bash
# Cai lan dau
./setup_omnivoice.sh

# Chay
./start_all.sh

# Truy cap
# http://<IP-server>:7862

# Dung
./stop_all.sh
```
