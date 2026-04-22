#!/usr/bin/env python3
"""
客房语音/电话 MQTT 联调：模拟来电、下行试播、观察上行（可选回环）。

依赖: pip install paho-mqtt

示例（Broker 与 global_config.h 一致，房号 301）:
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 listen
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 incoming
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 tone
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 tone --freq 800 --duration 2.0
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 sweep
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 play-wav --file demo.wav
  python mqtt_voice_test.py --host 172.20.10.3 --room 301 agent-start
"""
from __future__ import annotations

import argparse
import base64
import json
import math
import struct
import sys
import time
import wave

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("请先安装: pip install paho-mqtt", file=sys.stderr)
    sys.exit(1)


def device_id(room: str) -> str:
    return f"room_{room}"


def cmd_payload(room: str, cmd_id: int, command_type: str, **extra) -> str:
    body: dict = {
        "command_id": cmd_id,
        "device_id": device_id(room),
        "command_type": command_type,
    }
    body.update(extra)
    return json.dumps(body, ensure_ascii=False)


# 采样率与固件 HAL_AUDIO_SAMPLE_RATE_HZ 保持一致（32 kHz：保证 I2S BCLK 2.048 MHz，
# 在常见 MEMS 麦克（MSM261 / ICS-43434 / INMP441）的稳定工作区间内）。
SAMPLE_RATE_HZ = 32000


def pcm16_tone(freq_hz: float, duration_s: float, sample_rate: int = SAMPLE_RATE_HZ) -> bytes:
    n = int(sample_rate * duration_s)
    out = bytearray()
    for i in range(n):
        t = i / sample_rate
        s = int(26000 * math.sin(2 * math.pi * freq_hz * t))
        s = max(-32767, min(32767, s))
        out += struct.pack("<h", s)
    return bytes(out)


def pcm16_sweep(f0: float, f1: float, duration_s: float, sample_rate: int = SAMPLE_RATE_HZ) -> bytes:
    """线性频率扫频（f0 → f1），用来听失真/底噪，频率范围内均匀覆盖。"""
    n = int(sample_rate * duration_s)
    out = bytearray()
    phase = 0.0
    for i in range(n):
        t = i / sample_rate
        f = f0 + (f1 - f0) * (t / duration_s)
        phase += 2 * math.pi * f / sample_rate
        s = int(22000 * math.sin(phase))
        s = max(-32767, min(32767, s))
        out += struct.pack("<h", s)
    return bytes(out)


def load_wav_as_s16_mono(path: str, target_rate: int = SAMPLE_RATE_HZ) -> bytes:
    """读取任意 16-bit PCM WAV（单/双声道任意采样率），返回 target_rate 单声道 s16le 字节流。
    用线性插值重采样，仅靠标准库 wave+struct，足够调测使用。"""
    with wave.open(path, "rb") as w:
        nchan = w.getnchannels()
        sampwidth = w.getsampwidth()
        src_rate = w.getframerate()
        nframes = w.getnframes()
        raw = w.readframes(nframes)
    if sampwidth != 2:
        raise ValueError(f"仅支持 16-bit PCM WAV, got sampwidth={sampwidth}")

    samples = list(struct.unpack(f"<{nframes * nchan}h", raw))
    if nchan == 2:
        mono = [(samples[i * 2] + samples[i * 2 + 1]) // 2 for i in range(nframes)]
    elif nchan == 1:
        mono = samples
    else:
        raise ValueError(f"仅支持 mono 或 stereo WAV, got nchan={nchan}")

    if src_rate != target_rate:
        ratio = target_rate / src_rate
        out_len = int(len(mono) * ratio)
        resampled = [0] * out_len
        for i in range(out_len):
            x = i / ratio
            i0 = int(x)
            i1 = min(i0 + 1, len(mono) - 1)
            frac = x - i0
            resampled[i] = int(mono[i0] * (1 - frac) + mono[i1] * frac)
        mono = resampled
        print(f"  重采样 {src_rate} → {target_rate} Hz, frames {nframes} → {out_len}", flush=True)

    # 保底裁剪到 s16 范围
    out = bytearray()
    for s in mono:
        if s > 32767:
            s = 32767
        elif s < -32768:
            s = -32768
        out += struct.pack("<h", s)
    return bytes(out)


def publish_pcm_chunked(client, topic: str, pcm: bytes, chunk_bytes: int = 4096,
                        chunk_interval: float = 0.060) -> None:
    """按 (chunk_bytes, chunk_interval) 节拍分块推送 PCM 到下行 topic。

    速率匹配原则（非常关键，否则会播几秒就变噪声）：
    - 32kHz/16-bit mono 每秒消费 64000 B；4096B = 64 ms 的音频
    - 发送间隔如果 < 64 ms，PC 会比设备播快，设备端队列必然溢出丢包
    - 这里用 60 ms：比 64 ms 略快约 6%，给 I2S TX DMA 一点领先就够了，
      也给 WiFi / MQTT 经线抖动留了余地；稳态下设备播放队列保持在 1–2 项，
      绝不会堆到 16 槽上限；xQueueSend 100 ms 超时只在极端抖动下生效。"""
    total = len(pcm)
    sent = 0
    for off in range(0, total, chunk_bytes):
        seg = pcm[off : off + chunk_bytes]
        client.publish(topic, downlink_json(seg), qos=1)
        sent += len(seg)
        time.sleep(chunk_interval)
    print(f"  下发完成: {sent}/{total} bytes, chunk={chunk_bytes} interval={chunk_interval*1000:.0f}ms",
          flush=True)


def downlink_json(pcm_bytes: bytes) -> str:
    b64 = base64.standard_b64encode(pcm_bytes).decode("ascii")
    return json.dumps(
        {
            "device_id": "ignored-by-firmware",
            "format": "pcm_s16le",
            "sample_rate": SAMPLE_RATE_HZ,
            "pcm_base64": b64,
        },
        ensure_ascii=False,
    )


def main() -> None:
    p = argparse.ArgumentParser(description="客房 MQTT 语音/电话联调")
    p.add_argument("--host", default="172.20.10.3", help="MQTT broker")
    p.add_argument("--port", type=int, default=1883)
    p.add_argument("--room", default="301", help="房号")
    sub = p.add_subparsers(dest="action", required=True)

    sub.add_parser("listen", help="订阅上行 topic，打印收到的 JSON（短打印 pcm 长度）")
    sub.add_parser("incoming", help="下发 incoming_call（请在设备上 PTT 短按接听后开始上行）")
    p_tone = sub.add_parser("tone", help="向下行 topic 发正弦音调（默认 1kHz / 0.35s）")
    p_tone.add_argument("--freq", type=float, default=1000.0, help="频率 Hz (默认 1000)")
    p_tone.add_argument("--duration", type=float, default=0.35, help="时长秒 (默认 0.35)")
    p_sweep = sub.add_parser("sweep", help="线性扫频（默认 200→4000Hz / 3s），听失真/底噪")
    p_sweep.add_argument("--f0", type=float, default=200.0, help="起始频率 Hz (默认 200)")
    p_sweep.add_argument("--f1", type=float, default=4000.0, help="结束频率 Hz (默认 4000)")
    p_sweep.add_argument("--duration", type=float, default=3.0, help="时长秒 (默认 3.0)")
    p_wav = sub.add_parser("play-wav", help="播放本地 WAV 文件（16-bit PCM，任意采样率/声道）")
    p_wav.add_argument("--file", required=True, help="WAV 文件路径")
    sub.add_parser("agent-start", help="下发 agent_session_start，打开窗口后按住 PTT 说话看上行")
    sub.add_parser("loopback", help="订阅上行并实时回灌到下行（会边说边放，易啸叫）")
    sub.add_parser("loopback-once", help="缓存一轮上行，收到 eos 后一次性回放（说完再播）")
    sub.add_parser("hangup", help="hangup_call")
    sub.add_parser("agent-end", help="agent_session_end")

    args = p.parse_args()
    did = device_id(args.room)
    uplink_topic = f"hotel/device/audio/uplink/{did}"
    downlink_topic = f"hotel/device/audio/downlink/{did}"
    cmd_topic = f"hotel/device/command/room/{did}"

    client_id = f"voice_test_{args.room}_{args.action}_{int(time.time())}"
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    except AttributeError:
        client = mqtt.Client(client_id=client_id)
    client.connect(args.host, args.port, keepalive=60)

    if args.action == "listen":

        def on_msg(_c, _u, msg):
            try:
                o = json.loads(msg.payload.decode("utf-8"))
            except Exception as e:
                print("parse err", e, msg.payload[:200])
                return
            if o.get("eos"):
                print("UPLINK eos", o.get("session"), "seq=", o.get("seq"))
                return
            b64 = o.get("pcm_base64") or ""
            pcm_len = len(base64.standard_b64decode(b64)) if b64 else 0
            print(
                "UPLINK",
                o.get("session"),
                "seq=",
                o.get("seq"),
                "call_id=",
                o.get("call_id", ""),
                "pcm_bytes=",
                pcm_len,
            )

        client.on_message = on_msg
        client.subscribe(uplink_topic, qos=1)
        client.loop_start()
        print("订阅:", uplink_topic, "Ctrl+C 结束")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        client.loop_stop()
        return

    if args.action == "incoming":
        payload = cmd_payload(
            args.room,
            9001,
            "incoming_call",
            call_id="test-call-1",
            caller_id="test-desk",
        )
        client.publish(cmd_topic, payload, qos=1)
        print("已发 incoming_call →", cmd_topic)
        print("请在客房 PTT 短按接听，再用另一终端:", sys.argv[0], "listen ...")
        return

    if args.action == "tone":
        pcm = pcm16_tone(args.freq, args.duration)
        print(f"tone: freq={args.freq}Hz duration={args.duration}s "
              f"sr={SAMPLE_RATE_HZ} pcm_bytes={len(pcm)} → {downlink_topic}", flush=True)
        publish_pcm_chunked(client, downlink_topic, pcm)
        return

    if args.action == "sweep":
        pcm = pcm16_sweep(args.f0, args.f1, args.duration)
        print(f"sweep: {args.f0}→{args.f1}Hz duration={args.duration}s "
              f"sr={SAMPLE_RATE_HZ} pcm_bytes={len(pcm)} → {downlink_topic}", flush=True)
        publish_pcm_chunked(client, downlink_topic, pcm)
        return

    if args.action == "play-wav":
        try:
            pcm = load_wav_as_s16_mono(args.file, SAMPLE_RATE_HZ)
        except Exception as e:
            print(f"读取 WAV 失败: {e}", file=sys.stderr)
            sys.exit(2)
        dur = len(pcm) / 2 / SAMPLE_RATE_HZ
        print(f"play-wav: file={args.file} output sr={SAMPLE_RATE_HZ} "
              f"pcm_bytes={len(pcm)} ≈ {dur:.2f}s → {downlink_topic}", flush=True)
        publish_pcm_chunked(client, downlink_topic, pcm)
        return

    if args.action == "agent-start":
        payload = cmd_payload(args.room, 9002, "agent_session_start", window_ms=120000)
        client.publish(cmd_topic, payload, qos=1)
        print("已发 agent_session_start →", cmd_topic)
        print("请在 120s 内按住 PTT，并用 listen 观察上行")
        return

    if args.action == "loopback":

        def on_msg(c, _u, msg):
            try:
                o = json.loads(msg.payload.decode("utf-8"))
            except Exception as e:
                print("parse err", e, msg.payload[:200])
                return
            if o.get("eos"):
                print("LOOPBACK eos", "session=", o.get("session"), "seq=", o.get("seq"))
                return
            if o.get("format") != "pcm_s16le":
                return
            b64 = o.get("pcm_base64")
            if not isinstance(b64, str) or not b64:
                return
            # 直接把上行 PCM 回灌到下行，验证采音链路与喇叭链路闭环
            payload = json.dumps(
                {
                    "device_id": "loopback",
                    "format": "pcm_s16le",
                    "sample_rate": int(o.get("sample_rate", SAMPLE_RATE_HZ) or SAMPLE_RATE_HZ),
                    "pcm_base64": b64,
                },
                ensure_ascii=False,
            )
            c.publish(downlink_topic, payload, qos=1)
            print("LOOPBACK frame", "seq=", o.get("seq"), "->", downlink_topic)

        client.on_message = on_msg
        client.subscribe(uplink_topic, qos=1)
        client.loop_start()
        print("回灌已启动(client_id=", client_id, "): 订阅", uplink_topic, "并回发到", downlink_topic, "Ctrl+C 结束", flush=True)
        print("提示: 先发 agent-start，再按住 PTT 说话，松手结束一轮。")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        client.loop_stop()
        return

    if args.action == "loopback-once":
        cache_pcm = bytearray()
        cached_frames = 0
        last_seq = None
        last_session = None

        def on_msg(c, _u, msg):
            nonlocal cache_pcm, cached_frames, last_seq, last_session
            try:
                o = json.loads(msg.payload.decode("utf-8"))
            except Exception as e:
                print("parse err", e, msg.payload[:200])
                return

            last_session = o.get("session")
            last_seq = o.get("seq")
            if o.get("eos"):
                if not cache_pcm:
                    print("LOOPBACK-ONCE eos but no pcm", "session=", last_session, "seq=", last_seq, flush=True)
                    return
                total = len(cache_pcm)
                print(
                    f"LOOPBACK-ONCE playback session={last_session} seq={last_seq} "
                    f"pcm_bytes={total} frames={cached_frames}",
                    flush=True,
                )
                publish_pcm_chunked(c, downlink_topic, bytes(cache_pcm))
                cache_pcm.clear()
                cached_frames = 0
                return

            if o.get("format") != "pcm_s16le":
                return
            b64 = o.get("pcm_base64")
            if not isinstance(b64, str) or not b64:
                return
            try:
                pcm = base64.standard_b64decode(b64)
            except Exception as e:
                print("b64 err", e, flush=True)
                return
            cache_pcm.extend(pcm)
            cached_frames += 1
            if cached_frames % 10 == 1:
                print("LOOPBACK-ONCE caching", "frames=", cached_frames, "bytes=", len(cache_pcm), flush=True)

        client.on_message = on_msg
        client.subscribe(uplink_topic, qos=1)
        client.loop_start()
        print("回放模式已启动(client_id=", client_id, "): 先缓存上行，收到 eos 后一次性回放到", downlink_topic, flush=True)
        print("提示: 先发 agent-start，再按住 PTT 说话，松手后会回放刚才那句。")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        client.loop_stop()
        return

    if args.action == "hangup":
        client.publish(cmd_topic, cmd_payload(args.room, 9003, "hangup_call"), qos=1)
        print("已发 hangup_call")
        return

    if args.action == "agent-end":
        client.publish(cmd_topic, cmd_payload(args.room, 9004, "agent_session_end"), qos=1)
        print("已发 agent_session_end")
        return


if __name__ == "__main__":
    main()
