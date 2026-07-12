# -*- coding: utf-8 -*-
"""edge-tts 串流播放：音訊邊生成邊播，首聲約 1 秒。

用法：
  echo 文字 | python speak_stream.py - [voice]
  python speak_stream.py "文字" [voice]
需要 mpv 或 ffplay 其中之一（管道播放器，皆無視窗）。
找不到播放器時以 exit code 3 結束，讓外層 speak.ps1 退回整檔模式。
"""
import asyncio
import shutil
import subprocess
import sys
import time


async def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] != "-":
        text = sys.argv[1]
    else:
        text = sys.stdin.buffer.read().decode("utf-8")
    text = text.strip()
    if not text:
        sys.exit(2)
    voice = sys.argv[2] if len(sys.argv) > 2 else "zh-TW-YunJheNeural"

    import edge_tts

    mpv = shutil.which("mpv")
    if mpv:
        cmd = [mpv, "--no-video", "--really-quiet", "--keep-open=no", "-"]
    else:
        ffplay = shutil.which("ffplay")
        if not ffplay:
            sys.exit(3)
        cmd = [ffplay, "-nodisp", "-autoexit", "-loglevel", "quiet", "-i", "pipe:0"]

    t0 = time.perf_counter()
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    first = None
    com = edge_tts.Communicate(text, voice)
    async for chunk in com.stream():
        if chunk["type"] == "audio":
            if first is None:
                first = time.perf_counter() - t0
                print(f"first_sound_s={first:.1f}", flush=True)
            try:
                proc.stdin.write(chunk["data"])
            except (BrokenPipeError, OSError):
                break
    try:
        proc.stdin.close()
    except Exception:
        pass
    proc.wait()
    print(f"total_s={time.perf_counter() - t0:.1f}")


asyncio.run(main())
