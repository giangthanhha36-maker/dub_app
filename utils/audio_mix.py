"""Tron tieng goc video + audio long tieng roi mux vao video (ti le 3:7 mac dinh)."""

import os

from utils.ffmpeg_utils import run_ffmpeg


def mix_and_mux(
    video_in: str,
    tts_wav: str,
    output: str,
    orig_gain: float = 0.3,
    tts_gain: float = 0.7,
) -> str:
    if not os.path.exists(video_in):
        raise FileNotFoundError(f"Khong tim thay video nguon: {video_in}")
    if not os.path.exists(tts_wav):
        raise FileNotFoundError(f"Khong tim thay audio long tieng: {tts_wav}")

    filter_complex = (
        f"[0:a]volume={orig_gain}[a0];"
        f"[1:a]volume={tts_gain}[a1];"
        f"[a0][a1]amix=inputs=2:normalize=0:duration=first[aout]"
    )

    commands = [
        "-y",
        "-i", video_in,
        "-i", tts_wav,
        "-filter_complex", filter_complex,
        "-map", "0:v:0",
        "-map", "[aout]",
        "-c:v", "copy",
        "-c:a", "aac",
        "-b:a", "192k",
        output,
    ]

    if not run_ffmpeg(commands):
        raise RuntimeError(
            "ffmpeg tron audio that bai. Kiem tra video co luong audio goc va file dub.wav hop le."
        )
    return output
