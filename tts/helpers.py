"""Helper audio/SRT — tách từ audio.py, không phụ thuộc Gradio."""

from typing import List, Tuple

import numpy as np
import torch

# Tốc độ đọc trung bình (ký tự / giây) theo ngôn ngữ.
LANG_SPEED = {
    "vi": 22.0,
    "en": 15.0,
    "zh": 5.5,
    "ja": 8.0,
    "ko": 7.0,
    "default": 15.0,
}

MAX_SPEED_DEFAULT = 1.3

_VI_CHARS = set(
    "ăâđêôơưĂÂĐÊÔƠƯ"
    "áàảãạấầẩẫậắằẳẵặ"
    "éèẻẽẹếềểễệ"
    "íìỉĩị"
    "óòỏõọốồổỗộớờởỡợ"
    "úùủũụứừửữự"
    "ýỳỷỹỵ"
)


def get_best_device():
    """Auto-detect the best available device: CUDA > XPU > MPS > CPU."""
    if torch.cuda.is_available():
        return "cuda"
    if hasattr(torch, "xpu") and torch.xpu.is_available():
        return "xpu"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def pysrttime_to_seconds(t) -> float:
    """Đổi SubRipTime của pysrt sang số giây (float)."""
    return (
        t.hours * 3600
        + t.minutes * 60
        + t.seconds
        + t.milliseconds / 1000.0
    )


def combine_segments(
    segments: List[Tuple[float, np.ndarray]], sr: int
) -> np.ndarray:
    """Ghép nhiều đoạn audio vào một timeline duy nhất."""
    if not segments:
        return np.zeros(0, dtype=np.float32)

    total_samples = 0
    placed: List[Tuple[int, np.ndarray]] = []
    for pos, wf in segments:
        start_sample = int(round(pos * sr))
        end_sample = start_sample + len(wf)
        total_samples = max(total_samples, end_sample)
        placed.append((start_sample, wf))

    canvas = np.zeros(total_samples, dtype=np.float32)
    for start_sample, wf in placed:
        seg = apply_edge_fade(wf.astype(np.float32), sr)
        canvas[start_sample : start_sample + len(seg)] += seg

    np.clip(canvas, -1.0, 1.0, out=canvas)
    return canvas


def detect_rate_lang(text: str, ui_language: str = None) -> str:
    """Chọn mã ngôn ngữ (vi/en/zh/ja/ko/default) để tra bảng tốc độ."""
    if ui_language and ui_language != "Auto":
        l = ui_language.lower()
        if "vietnam" in l:
            return "vi"
        if "english" in l:
            return "en"
        if "chinese" in l or "mandarin" in l:
            return "zh"
        if "japanese" in l:
            return "ja"
        if "korean" in l:
            return "ko"

    has_kana = has_hangul = has_cjk = has_vi = False
    for ch in text:
        code = ord(ch)
        if 0x3040 <= code <= 0x30FF:
            has_kana = True
        elif 0xAC00 <= code <= 0xD7A3 or 0x1100 <= code <= 0x11FF:
            has_hangul = True
        elif 0x4E00 <= code <= 0x9FFF:
            has_cjk = True
        elif ch in _VI_CHARS:
            has_vi = True

    if has_kana:
        return "ja"
    if has_hangul:
        return "ko"
    if has_cjk:
        return "zh"
    if has_vi:
        return "vi"
    return "default"


def estimate_natural_duration(text: str, rate_lang: str) -> float:
    """Ước lượng số giây cần để đọc text ở tốc độ tự nhiên."""
    n_chars = len("".join(text.split()))
    rate = LANG_SPEED.get(rate_lang, LANG_SPEED["default"])
    if rate <= 0:
        rate = LANG_SPEED["default"]
    return n_chars / rate


def apply_edge_fade(wf: np.ndarray, sr: int, fade_ms: float = 15.0) -> np.ndarray:
    """Bo nhẹ đầu/cuối đoạn audio để tránh tiếng tách/cụp khi nối."""
    n = len(wf)
    fade = int(sr * fade_ms / 1000.0)
    if n == 0 or fade <= 0:
        return wf
    fade = min(fade, n // 2)
    if fade <= 0:
        return wf
    out = wf.copy()
    ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)
    out[:fade] *= ramp
    out[-fade:] *= ramp[::-1]
    return out


def fit_to_length(wf: np.ndarray, target_len: int, sr: int) -> np.ndarray:
    """Co/giãn waveform cho vừa đúng target_len mẫu (hard-sync)."""
    n = len(wf)
    if target_len <= 0:
        return np.zeros(0, dtype=np.float32)
    if n == 0:
        return np.zeros(target_len, dtype=np.float32)

    wf = wf.astype(np.float32)
    if n > target_len:
        rate = n / float(target_len)
        try:
            import librosa

            wf = librosa.effects.time_stretch(wf, rate=rate)
        except Exception:
            idx = np.linspace(0, n - 1, target_len)
            wf = np.interp(idx, np.arange(n), wf).astype(np.float32)

        if len(wf) > target_len:
            wf = wf[:target_len]
        elif len(wf) < target_len:
            wf = np.pad(wf, (0, target_len - len(wf)))
    return wf.astype(np.float32)
