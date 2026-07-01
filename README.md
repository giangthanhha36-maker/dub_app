# dub_app — Long tieng video doc lap

Repo tu chua day du: upload video + file `.srt` → OmniVoice clone giong → ghep audio **30% goc / 70% dub** → video hoan chinh.

Khong phu thuoc pipeline OCR/xoa phu de/dich. Clone repo nay la du de chay tren server.

## Kien truc

```
Trinh duyet  →  app.py (:8000, conda omnivoice + GPU)
                    UI Gradio + OmniVoice engine (cung process)
```

**Mot process, mot Gradio** — khong con service API rieng tren cong 7861.

## Yeu cau

- Python 3.12 (conda env `omnivoice`)
- `ffmpeg` trong PATH
- GPU NVIDIA + driver (`nvidia-smi` chay duoc)
- Miniconda
- File `.srt` da chuan bi ben ngoai (timeline khop video)

## Cai dat lan dau

```bash
git clone <repo-dub_app>
cd dub_app

cp config-template.yaml config.yaml

chmod +x setup_omnivoice.sh run.sh start_all.sh stop_all.sh status.sh

# Cai env GPU + deps (chay 1 lan)
./setup_omnivoice.sh
```

## Chay

### Cach 1 — Mot lenh (khuyen nghi tren server)

```bash
./start_all.sh              # khoi dong background
./status.sh                 # xem trang thai
tail -f logs/ui.log         # doi "Model loaded." truoc khi long tieng
```

Dung tat ca:

```bash
./stop_all.sh
```

Mo trinh duyet: **http://&lt;IP-server&gt;:8000**

### Cach 2 — Foreground (khi debug)

```bash
./run.sh
```

### Cach 3 — CLI headless (khong can trinh duyet)

```bash
conda activate omnivoice
python -m pipeline.cli \
  --video input.mp4 \
  --srt input.srt \
  --ref-audio voice.wav \
  --language Vietnamese
```

### Link Gradio public (khong can mo firewall)

```bash
GRADIO_SHARE=1 ./start_all.sh
```

Chi tiet trien khai server: xem [SERVER.md](SERVER.md).

## Cau truc

```
dub_app/
├── app.py                    # UI Gradio + load OmniVoice engine
├── config-template.yaml
├── run.sh                    # Khoi dong app (conda omnivoice)
├── setup_omnivoice.sh        # Cai env omnivoice (1 lan)
├── start_all.sh              # Khoi dong background (1 lenh)
├── stop_all.sh               # Dung service (1 lenh)
├── status.sh                 # Xem trang thai
├── requirements-omnivoice.txt
├── tts/
│   ├── engine.py             # OmniVoiceEngine (logic TTS)
│   ├── srt_processor.py      # SRT -> waveform
│   └── helpers.py            # Audio helpers
├── pipeline/
│   ├── run.py                # video + SRT -> dub -> ghep
│   └── cli.py                # CLI headless
├── audio.py                  # DEPRECATED (tham chieu cu)
└── utils/                    # ffmpeg, audio mix 3:7
```

Output: `output/<ten_video>_<timestamp>/`

## Cau hinh

`config.yaml`:

```yaml
tts:
  model: "k2-fsa/OmniVoice"
  no_asr: false          # true = nhe VRAM
  num_step: 32
  max_speed: 1.3
  hard_sync: true

dub:
  orig_gain: 0.3
  tts_gain: 0.7

ui:
  port: 8000
```

Doi cong UI khi chay:

```bash
GRADIO_PORT=8080 ./run.sh
```

## Cong

| Cong | Dich vu |
|------|---------|
| 8000 | dub_app UI (mac dinh) |
