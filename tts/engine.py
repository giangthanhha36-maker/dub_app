"""OmniVoice engine — load model và sinh audio, không Gradio."""

import logging
import os
import threading
from typing import Any, Dict, Optional, Tuple

import numpy as np
import soundfile as sf
import torch
from omnivoice import OmniVoice, OmniVoiceGenerationConfig

from tts.helpers import get_best_device
from tts.srt_processor import srt_to_speech, srt_to_speech_sync

logger = logging.getLogger(__name__)


class OmniVoiceEngine:
    """Wrapper OmniVoice: load một lần, gọi trực tiếp từ pipeline."""

    def __init__(
        self,
        model_id: str = "k2-fsa/OmniVoice",
        device: Optional[str] = None,
        load_asr: bool = True,
        asr_model_name: str = "openai/whisper-large-v3-turbo",
    ):
        self.model_id = model_id
        self.device = device or get_best_device()
        self.load_asr = load_asr
        self.asr_model_name = asr_model_name
        self._model: Optional[OmniVoice] = None
        self._lock = threading.Lock()

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    @property
    def sampling_rate(self) -> int:
        self._ensure_loaded()
        return self._model.sampling_rate

    def load(self) -> "OmniVoiceEngine":
        """Tải model OmniVoice (idempotent)."""
        if self._model is not None:
            return self
        with self._lock:
            if self._model is not None:
                return self
            logger.info(
                "Loading OmniVoice from %s, device=%s ...",
                self.model_id,
                self.device,
            )
            self._model = OmniVoice.from_pretrained(
                self.model_id,
                device_map=self.device,
                dtype=torch.float16,
                load_asr=self.load_asr,
                asr_model_name=self.asr_model_name,
            )
            logger.info("OmniVoice model loaded.")
        return self

    def _ensure_loaded(self):
        if self._model is None:
            raise RuntimeError("Model chua duoc tai. Goi engine.load() truoc.")

    def generate_waveform(
        self,
        text: str,
        language: str = "Auto",
        ref_audio=None,
        instruct: str = "",
        num_step: int = 32,
        guidance_scale: float = 2.0,
        denoise: bool = True,
        speed: float = 1.0,
        duration: float = 0,
        preprocess_prompt: bool = True,
        postprocess_output: bool = True,
        ref_text: Optional[str] = None,
    ) -> Tuple[Optional[np.ndarray], str]:
        """Sinh waveform float [-1, 1] cho một câu text.

        Thu tu tham so khop srt_processor / audio.py (_gen_waveform).
        """
        self._ensure_loaded()
        if not text or not text.strip():
            return None, "Vui lòng nhập text cần đọc."

        gen_config = OmniVoiceGenerationConfig(
            num_step=int(num_step or 32),
            guidance_scale=float(guidance_scale) if guidance_scale is not None else 2.0,
            denoise=bool(denoise) if denoise is not None else True,
            preprocess_prompt=bool(preprocess_prompt),
            postprocess_output=bool(postprocess_output),
        )

        lang = language if (language and language != "Auto") else None
        kw: Dict[str, Any] = dict(
            text=text.strip(), language=lang, generation_config=gen_config
        )

        if speed is not None and float(speed) != 1.0:
            kw["speed"] = float(speed)
        if duration is not None and float(duration) > 0:
            kw["duration"] = float(duration)

        if ref_audio:
            kw["voice_clone_prompt"] = self._model.create_voice_clone_prompt(
                ref_audio=ref_audio,
                ref_text=ref_text,
            )

        if instruct and instruct.strip():
            kw["instruct"] = instruct.strip()

        try:
            with self._lock:
                audio = self._model.generate(**kw)
        except Exception as e:
            return None, f"Error: {type(e).__name__}: {e}"

        waveform = np.asarray(audio[0], dtype=np.float32)
        return waveform, "Done."

    def _gen_waveform_for_srt(
        self,
        *,
        text: str,
        language: str = "Auto",
        ref_audio=None,
        instruct: str = "",
        num_step: int = 32,
        guidance_scale: float = 2.0,
        denoise: bool = True,
        speed: float = 1.0,
        duration: float = 0,
        preprocess_prompt: bool = True,
        postprocess_output: bool = True,
        ref_text: Optional[str] = None,
    ) -> Tuple[Optional[np.ndarray], str]:
        """Adapter cho srt_processor — chi nhan keyword arguments."""
        return self.generate_waveform(
            text=text,
            language=language,
            ref_audio=ref_audio,
            instruct=instruct,
            num_step=num_step,
            guidance_scale=guidance_scale,
            denoise=denoise,
            speed=speed,
            duration=duration,
            preprocess_prompt=preprocess_prompt,
            postprocess_output=postprocess_output,
            ref_text=ref_text,
        )

    def srt_to_wav(
        self,
        srt_path: str,
        out_wav: str,
        *,
        ref_audio: Optional[str] = None,
        ref_text: Optional[str] = None,
        language: str = "Vietnamese",
        num_step: int = 32,
        guidance_scale: float = 2.0,
        denoise: bool = True,
        max_speed: float = 1.3,
        hard_sync: bool = True,
        log_fn=None,
    ) -> str:
        """Chuyển SRT thành file WAV long tiếng."""
        self._ensure_loaded()

        if not os.path.exists(srt_path):
            raise FileNotFoundError(f"Khong tim thay file SRT: {srt_path}")

        if out_wav is None:
            base, _ = os.path.splitext(srt_path)
            out_wav = f"{base}_dub.wav"

        gen_fn = self._gen_waveform_for_srt
        sr = self.sampling_rate

        common = dict(
            language=language or "Auto",
            ref_audio=ref_audio,
            ref_text=(ref_text or "").strip() or None,
            instruct="",
            num_step=int(num_step),
            guidance_scale=float(guidance_scale),
            denoise=bool(denoise),
            preprocess_prompt=True,
            postprocess_output=True,
        )

        if hard_sync:
            result, status = srt_to_speech_sync(
                srt_path,
                gen_fn,
                sr,
                max_speed=float(max_speed),
                **common,
            )
        else:
            result, status = srt_to_speech(
                srt_path,
                gen_fn,
                sr,
                speed=1.0,
                duration=0,
                fit_timeline=True,
                max_speed=float(max_speed),
                **common,
            )

        if log_fn:
            log_fn(status)

        if result is None:
            raise RuntimeError(status)

        sample_rate, waveform_i16 = result
        os.makedirs(os.path.dirname(os.path.abspath(out_wav)) or ".", exist_ok=True)
        sf.write(out_wav, waveform_i16, sample_rate, subtype="PCM_16")
        return out_wav
