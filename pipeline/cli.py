"""CLI headless: video + SRT -> video long tieng hoan chinh."""

import argparse
import logging
import os
import sys

APP_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

from app import _load_config, create_engine  # noqa: E402
from pipeline.run import run_dub_pipeline  # noqa: E402


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Long tieng video: video + SRT -> video hoan chinh",
    )
    parser.add_argument("--video", required=True, help="Duong dan video goc")
    parser.add_argument("--srt", required=True, help="Duong dan file .srt")
    parser.add_argument("--ref-audio", default=None, help="Audio mau clone giong")
    parser.add_argument("--ref-text", default=None, help="Loi thoai audio mau")
    parser.add_argument("--language", default="Vietnamese", help="Ngon ngu long tieng")
    parser.add_argument("--num-step", type=int, default=None, help="So buoc sinh audio")
    parser.add_argument("--max-speed", type=float, default=None, help="Gioi han tang toc")
    parser.add_argument(
        "--no-hard-sync",
        action="store_true",
        help="Tat che do neo cung timeline (mac dinh: bat)",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s: %(message)s",
    )

    cfg = _load_config()
    tts_cfg = cfg.get("tts") or {}
    dub_cfg = cfg.get("dub") or {}

    num_step = args.num_step if args.num_step is not None else int(tts_cfg.get("num_step", 32))
    max_speed = args.max_speed if args.max_speed is not None else float(tts_cfg.get("max_speed", 1.3))
    hard_sync = bool(tts_cfg.get("hard_sync", True)) and not args.no_hard_sync

    print("Dang tai model OmniVoice...")
    engine = create_engine(cfg)
    print("Model loaded.")

    def log_fn(msg):
        print(msg)

    out = run_dub_pipeline(
        video_path=args.video,
        srt_path=args.srt,
        engine=engine,
        ref_audio=args.ref_audio,
        ref_text=args.ref_text,
        language=args.language,
        num_step=num_step,
        max_speed=max_speed,
        hard_sync=hard_sync,
        orig_gain=float(dub_cfg.get("orig_gain", 0.3)),
        tts_gain=float(dub_cfg.get("tts_gain", 0.7)),
        log_fn=log_fn,
    )
    print(f"Ket qua: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
