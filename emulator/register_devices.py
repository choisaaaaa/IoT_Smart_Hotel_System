"""注册并审核所有模拟器设备"""
import requests
import json

base = "http://127.0.0.1:9000/api/v1"

login_resp = requests.post(f"{base}/auth/login", json={"phone": "13900000003", "password": "123123"})
token = login_resp.json().get("data", {}).get("token", "")
print(f"Login: {login_resp.status_code}")

headers = {"Authorization": f"Bearer {token}"}

devices_to_register = [
    {"device_id": "floor_03", "device_type": "floor", "device_name": "3F Floor Controller", "hotel_id": 9},
    {"device_id": "room_301", "device_type": "room", "device_name": "Room 301 Terminal", "hotel_id": 9, "room_number": "301"},
    {"device_id": "front_desk_01", "device_type": "front_desk", "device_name": "Front Desk Card Reader", "hotel_id": 9},
]

for dev in devices_to_register:
    dev["firmware_version"] = "v1.2.0-smart"
    dev["ip_address"] = "127.0.0.1"
    reg_resp = requests.post(f"{base}/devices/register", json=dev, headers=headers)
    reg_data = reg_resp.json()
    print(f"Register {dev['device_id']}: {reg_resp.status_code} status={reg_data.get('data', {}).get('status')} audit={reg_data.get('data', {}).get('audit_status')}")

devices_resp = requests.get(f"{base}/devices?audit_status=pending", headers=headers)
devices_data = devices_resp.json().get("data", {})
pending_devices = devices_data.get("devices", devices_data) if isinstance(devices_data, dict) else devices_data

if not isinstance(pending_devices, list):
    pending_devices = []

print(f"\nPending devices: {len(pending_devices)}")

for dev in pending_devices:
    dev_db_id = dev.get("id")
    dev_device_id = dev.get("device_id", "unknown")
    dev_type = dev.get("device_type", "")

    area = ""
    if "floor" in dev_type:
        area = "3F"
    elif "front" in dev_type:
        area = "Front Desk"
    else:
        area = "Room"

    audit_resp = requests.put(f"{base}/devices/{dev_db_id}/audit", json={
        "status": "approved",
        "area": area,
        "device_name": dev.get("device_name", dev_device_id)
    }, headers=headers)
    result = audit_resp.json()
    device_key = result.get("data", {}).get("device_key", "N/A")
    print(f"Audit {dev_device_id} (db_id={dev_db_id}): {audit_resp.status_code} key={device_key}")

print("\n=== Device registration and audit complete ===")
