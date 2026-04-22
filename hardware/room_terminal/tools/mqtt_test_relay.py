#!/usr/bin/env python3
"""
向客房 MQTT 下发规范指令，用于继电器/门锁等联调。
主题: hotel/device/command/room/room_<房号>
负载: {"command_id":int,"device_id":"room_xxx","command_type":"..."}

示例:
  python mqtt_test_relay.py --suite all
  python mqtt_test_relay.py --suite light --delay 1.0
"""
from __future__ import annotations

import argparse
import json
import sys
import time

try:
    import paho.mqtt.publish as publish
except ImportError:
    print("请先安装: pip install paho-mqtt", file=sys.stderr)
    sys.exit(1)

# 与 main.c execute_room_command 中 command_type 一致
SUITES: dict[str, list[str]] = {
    "light": ["light_on", "light_off"],
    "air": ["air_on", "air_off"],
    "curtain": ["curtain_open", "curtain_close"],
    "door": ["door_unlock", "door_lock"],
    "all": [
        "light_on",
        "light_off",
        "air_on",
        "air_off",
        "curtain_open",
        "curtain_close",
        "door_unlock",
        "door_lock",
    ],
}


def main() -> None:
    p = argparse.ArgumentParser(description="客房 MQTT 继电器/通道联调")
    p.add_argument("--host", default="172.20.10.3", help="MQTT broker 主机")
    p.add_argument("--port", type=int, default=1883)
    p.add_argument("--room", default="301", help="房号 → device_id=room_<房号>")
    p.add_argument(
        "--suite",
        choices=list(SUITES.keys()),
        default="all",
        help="all=四路各开再关；light/air/curtain/door=单路一对",
    )
    p.add_argument(
        "--delay",
        type=float,
        default=0.7,
        help="每条指令之间的间隔(秒)，便于听继电器/看灯",
    )
    p.add_argument(
        "--start-id",
        type=int,
        default=92000,
        help="command_id 起始值，每条 +1",
    )
    args = p.parse_args()

    device_id = f"room_{args.room}"
    topic = f"hotel/device/command/room/{device_id}"
    cmds = SUITES[args.suite]

    def send(cmd_type: str, cmd_id: int) -> None:
        payload = json.dumps(
            {"command_id": cmd_id, "device_id": device_id, "command_type": cmd_type},
            separators=(",", ":"),
        )
        publish.single(topic, payload=payload, hostname=args.host, port=args.port, qos=0)
        print(f"PUBLISH {topic}\n  {payload}")

    cmd_id = args.start_id
    for i, cmd_type in enumerate(cmds):
        send(cmd_type, cmd_id)
        cmd_id += 1
        if i < len(cmds) - 1 and args.delay > 0:
            time.sleep(args.delay)

    print("完成。")


if __name__ == "__main__":
    main()
