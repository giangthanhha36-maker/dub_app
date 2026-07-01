# ===========================================================================
# DEPRECATED — Client goi service OmniVoice qua Gradio API (audio.py :7861).
#
# Da thay bang goi truc tiep: tts/engine.py -> OmniVoiceEngine.srt_to_wav()
# Xem: pipeline/run.py, app.py
# ===========================================================================

# """
# Client goi service OmniVoice (audio.py) de tao audio long tieng.
#
# Service phai chay truoc, vi du:
#     ./run_omnivoice.sh   (cong 7861)
#
# Endpoint: api_name="/srt_to_speech"
# """
#
# import os
# import shutil
#
#
# def generate_dub(
#     srt_path: str,
#     server_url: str = "http://127.0.0.1:7861",
#     ref_audio: str = None,
#     ref_text: str = None,
#     language: str = "Auto",
#     num_step: int = 32,
#     guidance_scale: float = 2.0,
#     denoise: bool = True,
#     max_speed: float = 1.3,
#     hard_sync: bool = True,
#     out_wav: str = None,
# ) -> str:
#     from gradio_client import Client, handle_file
#
#     if not os.path.exists(srt_path):
#         raise FileNotFoundError(f"Khong tim thay file SRT: {srt_path}")
#
#     if out_wav is None:
#         base, _ = os.path.splitext(srt_path)
#         out_wav = f"{base}_dub.wav"
#
#     client = Client(server_url)
#
#     srt_arg = handle_file(srt_path)
#     ref_arg = handle_file(ref_audio) if ref_audio else None
#
#     result = client.predict(
#         srt_arg,
#         language or "Auto",
#         ref_arg,
#         ref_text or "",
#         "",
#         int(num_step),
#         float(guidance_scale),
#         bool(denoise),
#         1.0,
#         0,
#         True,
#         True,
#         True,
#         float(max_speed),
#         bool(hard_sync),
#         api_name="/srt_to_speech",
#     )
#
#     audio_part = result[0] if isinstance(result, (list, tuple)) else result
#     audio_src = _extract_path(audio_part)
#     if not audio_src or not os.path.exists(audio_src):
#         raise RuntimeError(
#             f"Service OmniVoice khong tra ve file audio hop le (nhan: {audio_part!r}). "
#             f"Kiem tra service dang chay tai {server_url}"
#         )
#
#     shutil.copy(audio_src, out_wav)
#     return out_wav
#
#
# def _extract_path(audio_part):
#     if audio_part is None:
#         return None
#     if isinstance(audio_part, str):
#         return audio_part
#     if isinstance(audio_part, dict):
#         for key in ("path", "name", "value", "url"):
#             if audio_part.get(key):
#                 return audio_part[key]
#         return None
#     if isinstance(audio_part, (list, tuple)) and audio_part:
#         return _extract_path(audio_part[0])
#     return None
