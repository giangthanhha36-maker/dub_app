"""Pipeline long tieng: video + SRT -> dub.wav -> ghep 3:7 vao video."""

import os
import shutil
from datetime import datetime

from client.tts_client import generate_dub
from utils.audio_mix import mix_and_mux

APP_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_ROOT = os.path.join(APP_DIR, "output")


def run_dub_pipeline(
    video_path: str,
    srt_path: str,
    *,
    server_url: str,
    ref_audio: str = None,
    ref_text: str = None,
    language: str = "Vietnamese",
    num_step: int = 32,
    max_speed: float = 1.3,
    hard_sync: bool = True,
    orig_gain: float = 0.3,
    tts_gain: float = 0.7,
    log_fn=None,
) -> str:
    """
    Tao audio long tieng tu SRT (OmniVoice) roi ghep vao video goc.

    Tra ve duong dan video ket qua.
    """
    def log(msg):
        if log_fn:
            log_fn(msg)

    if not video_path or not os.path.exists(video_path):
        raise FileNotFoundError("Chua chon video hoac file khong ton tai.")
    if not srt_path or not os.path.exists(srt_path):
        raise FileNotFoundError("Chua chon file .srt hoac file khong ton tai.")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base_name = os.path.splitext(os.path.basename(video_path))[0]
    work_dir = os.path.join(OUTPUT_ROOT, f"{base_name}_{timestamp}")
    os.makedirs(work_dir, exist_ok=True)

    ext = os.path.splitext(video_path)[1] or ".mp4"
    local_video = os.path.join(work_dir, base_name + ext)
    shutil.copy(video_path, local_video)
    log(f"Da copy video vao: {local_video}")

    local_srt = os.path.join(work_dir, os.path.basename(srt_path))
    if os.path.abspath(srt_path) != os.path.abspath(local_srt):
        shutil.copy(srt_path, local_srt)
    else:
        local_srt = srt_path

    tts_wav = os.path.join(work_dir, f"{base_name}_dub.wav")
    log(f"Tao giong long tieng (OmniVoice: {server_url})...")
    generate_dub(
        srt_path=local_srt,
        server_url=server_url,
        ref_audio=ref_audio,
        ref_text=(ref_text or "").strip() or None,
        language=language,
        num_step=int(num_step),
        max_speed=float(max_speed),
        hard_sync=bool(hard_sync),
        out_wav=tts_wav,
    )
    log(f"Da tao dub.wav: {tts_wav}")

    dub_video = os.path.join(work_dir, f"{base_name}_dub{ext}")
    log(f"Tron tieng goc {int(orig_gain * 100)}% + long tieng {int(tts_gain * 100)}%...")
    mix_and_mux(
        video_in=local_video,
        tts_wav=tts_wav,
        output=dub_video,
        orig_gain=float(orig_gain),
        tts_gain=float(tts_gain),
    )
    log(f"Video hoan chinh: {dub_video}")
    return dub_video
