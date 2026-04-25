#!/usr/bin/env python3
"""
生成客房刷卡提示 PCM（16kHz 单声道 s16le），输出到 main/welcome_card.pcm 与 main/invalid_card.pcm。

引擎（按优先级，可用 --engine 强制）:
  1) 讯飞在线语音合成（流式 WebAPI，aue=raw，与固件 hal 一致）
     需环境变量:
       XFYUN_APP_ID      控制台应用 AppID
       XFYUN_API_KEY     流式语音合成 APIKey
       XFYUN_API_SECRET  APISecret
     可选: XFYUN_TTS_VCN  发音人，默认 xiaoyan（以控制台已开通的为准）

  2) edge-tts + ffmpeg: pip install edge-tts，且本机有 ffmpeg

  3) 自备 WAV: python gen_card_voice_pcm.py --from-wav welcome.wav invalid.wav

用法:
  set XFYUN_APP_ID=... & set XFYUN_API_KEY=... & set XFYUN_API_SECRET=...
  python gen_card_voice_pcm.py --engine iflytek

  python gen_card_voice_pcm.py --engine auto    # 有讯飞环境变量则讯飞，否则 edge-tts
  python gen_card_voice_pcm.py --from-wav a.wav b.wav
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import hmac
import json
import os
import subprocess
import sys
import time
from email.utils import formatdate
from pathlib import Path
from urllib.parse import urlencode

MAIN_DIR = Path(__file__).resolve().parent.parent / "main"
WELCOME_TEXT = (
    "欢迎来到酒店客房，有任何需求可以唤醒酒店管家为您提供帮助，祝您收获一个舒适的体验。"
)
INVALID_TEXT = "非本房间房卡"

IFLYTEK_WS_HOST = "tts-api.xfyun.cn"
IFLYTEK_WS_PATH = "/v2/tts"


def _iflytek_build_ws_url(api_key: str, api_secret: str) -> str:
    """鉴权 URL，见 https://www.xfyun.cn/doc/tts/online_tts/API.html"""
    date = formatdate(timeval=None, localtime=False, usegmt=True)
    signature_origin = "\n".join(
        [
            f"host: {IFLYTEK_WS_HOST}",
            f"date: {date}",
            f"GET {IFLYTEK_WS_PATH} HTTP/1.1",
        ]
    )
    signature_sha = hmac.new(
        api_secret.encode("utf-8"),
        signature_origin.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).digest()
    signature = base64.b64encode(signature_sha).decode("utf-8")
    authorization_origin = (
        f'api_key="{api_key}", algorithm="hmac-sha256", '
        f'headers="host date request-line", signature="{signature}"'
    )
    authorization = base64.b64encode(authorization_origin.encode("utf-8")).decode("utf-8")
    params = {"authorization": authorization, "date": date, "host": IFLYTEK_WS_HOST}
    return f"wss://{IFLYTEK_WS_HOST}{IFLYTEK_WS_PATH}?{urlencode(params)}"


def _iflytek_synthesize_pcm(app_id: str, api_key: str, api_secret: str, text: str, vcn: str) -> bytes:
    try:
        import websocket
    except ImportError:
        print("讯飞合成需要: pip install websocket-client", file=sys.stderr)
        raise

    url = _iflytek_build_ws_url(api_key, api_secret)
    ws = websocket.create_connection(url, timeout=60)

    payload = {
        "common": {"app_id": app_id},
        "business": {
            "aue": "raw",
            "auf": "audio/L16;rate=16000",
            "vcn": vcn,
            "speed": 52,
            "volume": 55,
            "pitch": 50,
            "tte": "UTF8",
        },
        "data": {
            "status": 2,
            "text": base64.b64encode(text.encode("utf-8")).decode("ascii"),
        },
    }
    ws.send(json.dumps(payload))

    chunks: list[bytes] = []
    while True:
        raw = ws.recv()
        if not raw:
            continue
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue
        code = msg.get("code")
        if code is not None and code != 0:
            ws.close()
            raise RuntimeError(f"讯飞 TTS 错误: code={code} message={msg.get('message')}")

        data = msg.get("data")
        if not data:
            continue
        audio_b64 = data.get("audio")
        if audio_b64:
            chunks.append(base64.b64decode(audio_b64))
        if data.get("status") == 2:
            break

    ws.close()
    return b"".join(chunks)


def _iflytek_env_ok() -> bool:
    return all(
        os.environ.get(k)
        for k in ("XFYUN_APP_ID", "XFYUN_API_KEY", "XFYUN_API_SECRET")
    )


async def _edge_tts_to_mp3(text: str, out_mp3: Path) -> None:
    import edge_tts

    voice = "zh-CN-XiaoxiaoNeural"
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(str(out_mp3))


def _ffmpeg_to_pcm16_mono_16k(in_audio: Path, out_pcm: Path) -> None:
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(in_audio),
        "-f",
        "s16le",
        "-ac",
        "1",
        "-ar",
        "16000",
        str(out_pcm),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _write_pair_iflytek(welcome_pcm: Path, invalid_pcm: Path) -> None:
    app_id = os.environ["XFYUN_APP_ID"].strip()
    api_key = os.environ["XFYUN_API_KEY"].strip()
    api_secret = os.environ["XFYUN_API_SECRET"].strip()
    vcn = os.environ.get("XFYUN_TTS_VCN", "xiaoyan").strip()

    print("讯飞合成中（欢迎语）…")
    w = _iflytek_synthesize_pcm(app_id, api_key, api_secret, WELCOME_TEXT, vcn)
    welcome_pcm.write_bytes(w)
    print("讯飞合成中（非法卡）…")
    inv = _iflytek_synthesize_pcm(app_id, api_key, api_secret, INVALID_TEXT, vcn)
    invalid_pcm.write_bytes(inv)


def _write_pair_edge(welcome_pcm: Path, invalid_pcm: Path) -> None:
    try:
        import edge_tts  # noqa: F401
    except ImportError:
        print("请安装: pip install edge-tts", file=sys.stderr)
        raise

    tmp_w = MAIN_DIR / "_tmp_welcome.mp3"
    tmp_i = MAIN_DIR / "_tmp_invalid.mp3"

    async def _run() -> None:
        await _edge_tts_to_mp3(WELCOME_TEXT, tmp_w)
        await _edge_tts_to_mp3(INVALID_TEXT, tmp_i)

    asyncio.run(_run())
    _ffmpeg_to_pcm16_mono_16k(tmp_w, welcome_pcm)
    _ffmpeg_to_pcm16_mono_16k(tmp_i, invalid_pcm)
    tmp_w.unlink(missing_ok=True)
    tmp_i.unlink(missing_ok=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="生成刷卡语音提示 PCM（16k s16le mono）")
    ap.add_argument(
        "--engine",
        choices=("auto", "iflytek", "edge"),
        default="auto",
        help="auto：优先讯飞（环境变量齐全），否则 edge-tts",
    )
    ap.add_argument("--from-wav", nargs=2, metavar=("WELCOME_WAV", "INVALID_WAV"))
    args = ap.parse_args()
    MAIN_DIR.mkdir(parents=True, exist_ok=True)
    welcome_pcm = MAIN_DIR / "welcome_card.pcm"
    invalid_pcm = MAIN_DIR / "invalid_card.pcm"

    if args.from_wav:
        w, inv = Path(args.from_wav[0]), Path(args.from_wav[1])
        if not w.is_file() or not inv.is_file():
            print("WAV 文件不存在", file=sys.stderr)
            return 1
        _ffmpeg_to_pcm16_mono_16k(w, welcome_pcm)
        _ffmpeg_to_pcm16_mono_16k(inv, invalid_pcm)
        print("已写入:", welcome_pcm, invalid_pcm)
        return 0

    engine = args.engine
    if engine == "auto":
        engine = "iflytek" if _iflytek_env_ok() else "edge"

    try:
        if engine == "iflytek":
            if not _iflytek_env_ok():
                print(
                    "讯飞需设置环境变量: XFYUN_APP_ID, XFYUN_API_KEY, XFYUN_API_SECRET",
                    file=sys.stderr,
                )
                return 1
            _write_pair_iflytek(welcome_pcm, invalid_pcm)
        else:
            _write_pair_edge(welcome_pcm, invalid_pcm)
    except Exception as e:
        print("合成失败:", e, file=sys.stderr)
        return 1

    print("已写入:", welcome_pcm, invalid_pcm)
    print("请重新 idf.py build（会嵌入 PCM）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
