# dub_app — Long tieng video doc lap

Package tu chua: upload video + file `.srt` → OmniVoice clone giong → ghep audio **30% goc / 70% dub** → video hoan chinh.

Khong phu thuoc pipeline OCR/xoa phu de/dich cua repo cha. Co the copy folder nay sang repo rieng.

## Yeu cau

- Python 3.10+
- `ffmpeg` trong PATH
- Service **OmniVoice** dang chay (tu repo cha: `../start_omnivoice.sh`, cong 7861)
- File `.srt` da chuan bi ben ngoai (timeline khop video)

## Cai dat

```bash
cd dub_app
cp config-template.yaml config.yaml
# Sua config.yaml neu OmniVoice o may khac

# Trong env ste (hoac venv):
pip install -r requirements.txt
chmod +x run.sh
```

## Chay

```bash
# Terminal 1 — OmniVoice (tu thu muc repo cha)
cd ..
./start_omnivoice.sh

# Terminal 2 — UI long tieng
cd dub_app
./run.sh
```

Mo trinh duyet: **http://&lt;IP-server&gt;:7862**

## Cau truc

```
dub_app/
├── app.py                 # UI Gradio
├── config-template.yaml
├── run.sh
├── pipeline/run.py        # video + SRT -> dub -> ghep
├── client/tts_client.py   # goi OmniVoice API
└── utils/                 # ffmpeg, audio mix 3:7
```

Output: `dub_app/output/<ten_video>_<timestamp>/`

## Tach thanh repo rieng

1. Copy nguyen folder `dub_app/`
2. Cai `requirements.txt`
3. Chay OmniVoice (`audio.py`) o bat ky dau, dat `tts.server_url` trong `config.yaml`
4. `./run.sh`

Khong can Paddle, OCR, STTN hay env `omnivoice` tren may chay UI — chi can `gradio_client` goi API.

## Cong thuong dung

| Cong | Dich vu |
|------|---------|
| 7862 | dub_app UI (mac dinh) |
| 7861 | OmniVoice API |
| 7860 | Pipeline chinh (repo cha, neu chay) |
