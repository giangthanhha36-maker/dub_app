"""Xử lý SRT -> waveform — tách từ audio.py, không Gradio."""

from typing import Callable, List, Optional, Tuple

import numpy as np
import pysrt

from tts.helpers import (
    MAX_SPEED_DEFAULT,
    apply_edge_fade,
    combine_segments,
    detect_rate_lang,
    estimate_natural_duration,
    fit_to_length,
    pysrttime_to_seconds,
)

GenWaveformFn = Callable[..., Tuple[Optional[np.ndarray], str]]


def open_srt(srt_file: str):
    """Đọc file SRT (utf-8 trước, fallback encoding tự đoán)."""
    try:
        return pysrt.open(srt_file, encoding="utf-8")
    except Exception:
        return pysrt.open(srt_file)


def srt_to_speech(
    srt_file: str,
    gen_waveform: GenWaveformFn,
    sampling_rate: int,
    *,
    language: str = "Auto",
    ref_audio=None,
    ref_text: Optional[str] = None,
    instruct: str = "",
    num_step: int = 32,
    guidance_scale: float = 2.0,
    denoise: bool = True,
    speed: float = 1.0,
    duration: float = 0,
    preprocess_prompt: bool = True,
    postprocess_output: bool = True,
    fit_timeline: bool = True,
    max_speed: float = MAX_SPEED_DEFAULT,
) -> Tuple[Optional[Tuple[int, np.ndarray]], str]:
    """Chuyển .srt thành audio theo timeline cộng dồn."""
    if not srt_file:
        return None, "Vui lòng tải lên một file .srt."

    try:
        srt_data = open_srt(srt_file)
    except Exception as e:
        return None, f"Không đọc được file SRT: {e}"

    if not srt_data or len(srt_data) == 0:
        return None, "File SRT rỗng hoặc sai định dạng."

    segments: List[Tuple[float, np.ndarray]] = []
    cursor_end = 0.0
    prev_srt_end = 0.0
    num_sped = 0
    max_factor = 1.0

    for idx, item in enumerate(srt_data):
        text = item.text.replace("\n", " ").strip()
        start = pysrttime_to_seconds(item.start)
        end = pysrttime_to_seconds(item.end)

        gap = start - prev_srt_end
        if gap < 0:
            gap = 0.0

        pos = cursor_end + gap

        if not text:
            cursor_end = pos
            prev_srt_end = end
            continue

        seg_speed = speed
        seg_duration = duration
        if fit_timeline:
            seg_duration = 0
            slot = end - start
            if slot > 0:
                rate_lang = detect_rate_lang(text, language)
                est = estimate_natural_duration(text, rate_lang)
                if est > slot:
                    seg_speed = min(est / slot, float(max_speed or MAX_SPEED_DEFAULT))
                    num_sped += 1
                    max_factor = max(max_factor, seg_speed)
                else:
                    seg_speed = 1.0

        waveform, msg = gen_waveform(
            text,
            language,
            ref_audio,
            instruct,
            num_step,
            guidance_scale,
            denoise,
            seg_speed,
            seg_duration,
            preprocess_prompt,
            postprocess_output,
            ref_text=ref_text or None,
        )
        if waveform is None:
            return None, f"Lỗi ở dòng {idx + 1}: {msg}"

        segments.append((pos, waveform))
        audio_len = len(waveform) / sampling_rate
        cursor_end = pos + audio_len
        prev_srt_end = end

    if not segments:
        return None, "Không có nội dung text nào để tạo audio."

    waveform_float = combine_segments(segments, sampling_rate)
    waveform_i16 = (waveform_float * 32767).astype(np.int16)
    total_dur = len(waveform_i16) / sampling_rate
    orig_dur = pysrttime_to_seconds(srt_data[-1].end)
    drift = total_dur - orig_dur
    status = (
        f"Done. Đã tạo {len(segments)} câu. "
        f"Tổng {total_dur:.1f}s (gốc {orig_dur:.1f}s, lệch {drift:+.1f}s). "
        f"Số câu phải tăng tốc: {num_sped}, hệ số lớn nhất: {max_factor:.2f}x."
    )
    return (sampling_rate, waveform_i16), status


def srt_to_speech_sync(
    srt_file: str,
    gen_waveform: GenWaveformFn,
    sampling_rate: int,
    *,
    language: str = "Auto",
    ref_audio=None,
    ref_text: Optional[str] = None,
    instruct: str = "",
    num_step: int = 32,
    guidance_scale: float = 2.0,
    denoise: bool = True,
    preprocess_prompt: bool = True,
    postprocess_output: bool = True,
    max_speed: float = MAX_SPEED_DEFAULT,
) -> Tuple[Optional[Tuple[int, np.ndarray]], str]:
    """Chuyển .srt thành audio neo cứng timeline (hard-sync)."""
    if not srt_file:
        return None, "Vui lòng tải lên một file .srt."

    try:
        srt_data = open_srt(srt_file)
    except Exception as e:
        return None, f"Không đọc được file SRT: {e}"

    if not srt_data or len(srt_data) == 0:
        return None, "File SRT rỗng hoặc sai định dạng."

    total_seconds = pysrttime_to_seconds(srt_data[-1].end)
    total_samples = int(round(total_seconds * sampling_rate))
    if total_samples <= 0:
        return None, "Timeline phụ đề không hợp lệ (độ dài <= 0)."
    canvas = np.zeros(total_samples, dtype=np.float32)

    num_done = 0
    num_compressed = 0
    max_factor = 1.0

    for idx, item in enumerate(srt_data):
        text = item.text.replace("\n", " ").strip()
        if not text:
            continue
        start = pysrttime_to_seconds(item.start)
        end = pysrttime_to_seconds(item.end)
        slot = end - start
        if slot <= 0:
            continue

        waveform, msg = gen_waveform(
            text,
            language,
            ref_audio,
            instruct,
            num_step,
            guidance_scale,
            denoise,
            1.0,
            slot,
            preprocess_prompt,
            postprocess_output,
            ref_text=ref_text or None,
        )
        if waveform is None:
            return None, f"Lỗi ở dòng {idx + 1}: {msg}"

        slot_samples = int(round(slot * sampling_rate))
        raw_len = len(waveform)
        if raw_len > slot_samples and slot_samples > 0:
            num_compressed += 1
            max_factor = max(max_factor, raw_len / float(slot_samples))

        seg = fit_to_length(waveform, slot_samples, sampling_rate)
        seg = apply_edge_fade(seg, sampling_rate)

        start_sample = int(round(start * sampling_rate))
        end_sample = start_sample + len(seg)
        if end_sample > total_samples:
            seg = seg[: total_samples - start_sample]
            end_sample = total_samples
        if start_sample < total_samples and len(seg) > 0:
            canvas[start_sample:end_sample] += seg
            num_done += 1

    np.clip(canvas, -1.0, 1.0, out=canvas)
    waveform_i16 = (canvas * 32767).astype(np.int16)
    total_dur = len(waveform_i16) / sampling_rate
    status = (
        f"Done (hard-sync). Đã tạo {num_done} câu, khớp đúng timeline. "
        f"Tổng {total_dur:.1f}s (== gốc, lệch 0.0s). "
        f"Số câu phải nén: {num_compressed}, hệ số nén lớn nhất: {max_factor:.2f}x."
    )
    return (sampling_rate, waveform_i16), status
