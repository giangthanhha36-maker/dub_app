"""
Giao dien Gradio cho long tieng doc lap (dub_app).

Luong:
  upload video goc + file .srt (da chuan bi ben ngoai)
  -> OmniVoice tao audio clone khop timeline
  -> tron tieng goc 30% + long tieng 70%
  -> xuat video hoan chinh

Chay:
    cd dub_app && ./run.sh
"""

import os
import queue
import sys
import threading
import traceback
from datetime import datetime

import gradio as gr
import yaml

# Them thu muc dub_app vao sys.path de import client/, pipeline/, utils/
APP_DIR = os.path.dirname(os.path.abspath(__file__))
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

from pipeline.run import run_dub_pipeline  # noqa: E402

LANGUAGES = [
    "Vietnamese",
    "English",
    "Chinese",
    "Japanese",
    "Korean",
    "French",
    "German",
    "Spanish",
    "Auto",
]


def _load_config():
    for path in ("config.yaml", "config-template.yaml"):
        cfg_path = os.path.join(APP_DIR, path)
        if os.path.exists(cfg_path):
            with open(cfg_path, "r", encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
    return {}


def _file_path(upload) -> str | None:
    """Lay duong dan tu gr.File / gr.Audio (filepath)."""
    if not upload:
        return None
    if isinstance(upload, str):
        return upload
    if isinstance(upload, dict):
        return upload.get("path") or upload.get("name")
    return str(upload)


def process_dub(
    video_path,
    srt_path,
    ref_audio,
    ref_text,
    language,
    omnivoice_url,
    num_step,
    max_speed,
    progress=gr.Progress(track_tqdm=True),
):
    cfg = _load_config()
    tts_cfg = cfg.get("tts") or {}
    dub_cfg = cfg.get("dub") or {}

    orig_gain = float(dub_cfg.get("orig_gain", 0.3))
    tts_gain = float(dub_cfg.get("tts_gain", 0.7))
    hard_sync = bool(tts_cfg.get("hard_sync", True))
    server_url = (omnivoice_url or "").strip() or tts_cfg.get(
        "server_url", "http://127.0.0.1:7861"
    )

    log_lines = []
    log_lock = threading.Lock()
    update_q = queue.Queue()
    state = {"video": None}

    def log(msg):
        stamp = datetime.now().strftime("%H:%M:%S")
        with log_lock:
            log_lines.append(f"[{stamp}] {msg}")
            return "\n".join(log_lines)

    def emit(video=None):
        if video is not None:
            state["video"] = video
        with log_lock:
            status = "\n".join(log_lines)
        update_q.put({"status": status, "video": state["video"]})

    def worker():
        try:
            if not video_path:
                log("Loi: chua chon video.")
                emit()
                return
            srt_file = _file_path(srt_path)
            if not srt_file:
                log("Loi: chua chon file .srt.")
                emit()
                return

            log("Bat dau xu ly long tieng...")
            emit()

            out_video = run_dub_pipeline(
                video_path=video_path,
                srt_path=srt_file,
                server_url=server_url,
                ref_audio=ref_audio,
                ref_text=ref_text,
                language=language or "Vietnamese",
                num_step=int(num_step),
                max_speed=float(max_speed),
                hard_sync=hard_sync,
                orig_gain=orig_gain,
                tts_gain=tts_gain,
                log_fn=log,
            )
            emit(out_video)
            log("HOAN TAT!")
            emit(out_video)
        except Exception as e:
            err = traceback.format_exc()
            log(f"Loi: {e}\n{err}")
            if "OmniVoice" in str(e) or "Connection" in str(e):
                log("Goi y: chay ./run_omnivoice.sh hoac kiem tra URL OmniVoice trong config.yaml.")
            emit()
        finally:
            update_q.put(None)

    threading.Thread(target=worker, daemon=True).start()

    last = {"status": "", "video": None}
    while True:
        try:
            item = update_q.get(timeout=0.5)
        except queue.Empty:
            yield last["status"], last["video"]
            continue
        if item is None:
            break
        last = item
        yield item["status"], item["video"]


def build_ui():
    cfg = _load_config()
    tts_cfg = cfg.get("tts") or {}
    dub_cfg = cfg.get("dub") or {}
    ui_cfg = cfg.get("ui") or {}

    with gr.Blocks(title="Video Dub — Long tieng") as demo:
        gr.Markdown(
            "# Long tieng video (dub_app)\n"
            "Upload **video goc** + file **.srt** (da chuan bi ben ngoai). "
            "OmniVoice tao giong clone, sau do ghep vao video voi ti le "
            f"**{int(float(dub_cfg.get('orig_gain', 0.3)) * 100)}% tieng goc / "
            f"{int(float(dub_cfg.get('tts_gain', 0.7)) * 100)}% long tieng**.\n\n"
            "Can service OmniVoice dang chay (`./run_omnivoice.sh`, cong 7861)."
        )

        with gr.Row():
            with gr.Column(scale=1):
                video_in = gr.Video(label="Video goc (co tieng goc)")
                srt_in = gr.File(
                    label="File phu de .srt (da dich / da chinh timeline)",
                    file_types=[".srt"],
                )
                ref_audio = gr.Audio(
                    label="Giong mau clone (3-10 giay)",
                    type="filepath",
                )
                ref_text = gr.Textbox(
                    label="Loi thoai giong mau (tuy chon)",
                    lines=2,
                )
                language = gr.Dropdown(
                    choices=LANGUAGES,
                    value="Vietnamese",
                    label="Ngon ngu long tieng",
                    allow_custom_value=True,
                )
                omnivoice_url = gr.Textbox(
                    label="OmniVoice server URL",
                    value=str(tts_cfg.get("server_url", "http://127.0.0.1:7861")),
                )
                with gr.Accordion("Tuy chon nang cao", open=False):
                    num_step = gr.Slider(
                        1, 64,
                        value=int(tts_cfg.get("num_step", 32)),
                        step=1,
                        label="num_step (cao = hay hon, cham hon)",
                    )
                    max_speed = gr.Slider(
                        1.0, 2.0,
                        value=float(tts_cfg.get("max_speed", 1.3)),
                        step=0.05,
                        label="Gioi han tang toc cau dai",
                    )
                run_btn = gr.Button("Bat dau long tieng", variant="primary")

            with gr.Column(scale=1):
                status_out = gr.Textbox(
                    label="Nhat ky tien do",
                    lines=20,
                    max_lines=40,
                    interactive=False,
                )
                video_out = gr.Video(label="Video hoan chinh")

        run_btn.click(
            fn=process_dub,
            inputs=[
                video_in,
                srt_in,
                ref_audio,
                ref_text,
                language,
                omnivoice_url,
                num_step,
                max_speed,
            ],
            outputs=[status_out, video_out],
        )

    return demo


if __name__ == "__main__":
    demo = build_ui()
    cfg = _load_config()
    ui_cfg = cfg.get("ui") or {}
    port = int(os.environ.get("GRADIO_PORT", ui_cfg.get("port", 7860)))
    share = os.environ.get("GRADIO_SHARE", "0") == "1"
    demo.queue().launch(
        server_name="0.0.0.0",
        server_port=port,
        share=share,
        inbrowser=False,
    )
