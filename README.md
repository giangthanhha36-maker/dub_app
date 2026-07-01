# dub_app — Long tieng video doc lap

Repo tu chua day du: upload video + file `.srt` → OmniVoice clone giong → ghep audio **30% goc / 70% dub** → video hoan chinh.

Khong phu thuoc pipeline OCR/xoa phu de/dich. Clone repo nay la du de chay tren server.

## Kien truc

```
Trinh duyet  →  dub_app UI (:7862, .venv)  →  OmniVoice API (:7861, conda omnivoice + GPU)
```

Hai service dung **hai moi truong Python tach biet** — khong tron chung env.

## Yeu cau

- Python 3.10+ (UI), Python 3.12 (OmniVoice API)
- `ffmpeg` trong PATH
- GPU NVIDIA + driver (`nvidia-smi` chay duoc) cho OmniVoice
- Miniconda (cho env `omnivoice`)
- File `.srt` da chuan bi ben ngoai (timeline khop video)

## Cai dat lan dau

```bash
git clone <repo-dub_app>
cd dub_app

cp config-template.yaml config.yaml
# Sua config.yaml neu OmniVoice chay may khac

chmod +x setup_omnivoice.sh run_omnivoice.sh run.sh start_all.sh stop_all.sh

# 1) Cai env GPU cho OmniVoice API (chay 1 lan)
./setup_omnivoice.sh

# 2) UI tu tao .venv khi chay ./run.sh lan dau
```

## Chay

### Cach 1 — Hai terminal (khuyen nghi khi test)

```bash
# Terminal 1 — OmniVoice API (doi "Model loaded.")
./run_omnivoice.sh

# Terminal 2 — UI long tieng
./run.sh
```

Mo trinh duyet: **http://&lt;IP-server&gt;:7862**

### Cach 2 — Mot lenh (chay nen)

```bash
./start_all.sh
tail -f logs/omnivoice.log   # doi Model loaded.
tail -f logs/ui.log
```

Dung dich vu:

```bash
./stop_all.sh
```

Chi tiet trien khai server (firewall, tmux, SSH tunnel): xem [SERVER.md](SERVER.md).

## Cau truc

```
dub_app/
├── app.py                    # UI Gradio (long tieng)
├── audio.py                  # OmniVoice API (SRT → speech)
├── config-template.yaml
├── run.sh                    # Khoi dong UI (.venv)
├── run_omnivoice.sh          # Khoi dong OmniVoice API (conda)
├── setup_omnivoice.sh        # Cai env omnivoice (1 lan)
├── start_all.sh              # Khoi dong ca 2 service (nền)
├── stop_all.sh               # Dung ca 2 service
├── requirements.txt          # Thu vien UI
├── requirements-omnivoice.txt
├── pipeline/run.py           # video + SRT → dub → ghep
├── client/tts_client.py      # goi OmniVoice API
└── utils/                    # ffmpeg, audio mix 3:7
```

Output: `output/<ten_video>_<timestamp>/`

## Cau hinh

`config.yaml`:

```yaml
tts:
  server_url: "http://127.0.0.1:7861"   # cung may
  # server_url: "http://<IP-GPU>:7861"  # may khac

ui:
  port: 7862
```

Doi cong UI khi chay:

```bash
GRADIO_PORT=8080 ./run.sh
```

## Cong thuong dung

| Cong | Dich vu |
|------|---------|
| 7862 | dub_app UI (mac dinh) |
| 7861 | OmniVoice API |

## OmniVoice tren may khac

1. Clone repo nay (hoac chi can `audio.py` + script omnivoice) len server GPU
2. `./setup_omnivoice.sh && ./run_omnivoice.sh`
3. Trong `config.yaml` cua dub_app: `tts.server_url: "http://<IP-GPU>:7861"`

May chay UI **khong can** GPU hay env `omnivoice` — chi can `gradio_client` goi API.
