"""Chay ffmpeg/ffprobe — bo LD_LIBRARY_PATH conda de tranh xung dot lib he thong."""

import os
import subprocess
from typing import Dict, List, Optional


def _ffmpeg_subprocess_env() -> Optional[Dict[str, str]]:
    env = os.environ.copy()
    env.pop("LD_LIBRARY_PATH", None)
    return env


def run_ffmpeg(args: List[str]) -> bool:
    commands = ["ffmpeg", "-hide_banner", "-loglevel", "error"]
    commands.extend(args)
    try:
        subprocess.check_output(
            commands, stderr=subprocess.STDOUT, env=_ffmpeg_subprocess_env()
        )
        return True
    except Exception as e:
        print(str(e))
    return False
