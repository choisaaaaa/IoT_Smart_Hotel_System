const mqtt = require('mqtt');

const BROKER_URL = 'mqtt://8.134.166.69:1883';
const AUTH = {
  username: 'iot_user',
  password: 'IotHotel2026',
  clean: true,
  connectTimeout: 4000,
  reconnectPeriod: 1000,
};

const COMMAND_ID = 99501;
const TEST_TIMEOUT_MS = 15000;
const clients = [];

function nowIso() {
  return new Date().toISOString();
}

function createClient(baseId) {
  const clientId = `${baseId}_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  const client = mqtt.connect(BROKER_URL, { ...AUTH, clientId });
  clients.push(client);
  return client;
}

function safeEndAll() {
  for (const c of clients) {
    try {
      c.end(true);
    } catch (_) {}
  }
}

function failAndExit(msg) {
  console.error(`❌ FAIL: ${msg}`);
  safeEndAll();
  process.exit(1);
}

function passAndExit(msg) {
  console.log(`✅ PASS: ${msg}`);
  safeEndAll();
  process.exit(0);
}

async function run() {
  const room = createClient('room301_smoke');
  const floor = createClient('floor03_smoke');
  const front = createClient('frontdesk_smoke');

  let roomReady = false;
  let floorReady = false;
  let frontReady = false;
  let commandSent = false;

  const timer = setTimeout(() => {
    failAndExit('timeout waiting for floor_reset round-trip');
  }, TEST_TIMEOUT_MS);

  function maybeSendCommand() {
    if (roomReady && floorReady && frontReady && !commandSent) {
      commandSent = true;
      const payload = {
        command_id: COMMAND_ID,
        device_id: 'floor_03',
        command_type: 'floor_reset',
        created_by: 'front_desk_pc',
        timestamp: nowIso(),
      };
      front.publish('hotel/device/command/floor/floor_03', JSON.stringify(payload), { qos: 1 }, (err) => {
        if (err) {
          clearTimeout(timer);
          failAndExit(`publish floor_reset failed: ${err.message}`);
          return;
        }
        console.log('📤 sent floor_reset command');
      });
    }
  }

  room.on('connect', () => {
    roomReady = true;
    room.publish('hotel/device/status/room/room_301', JSON.stringify({
      device_id: 'room_301',
      device_type: 'room',
      status: 'online',
      timestamp: nowIso(),
    }));
    maybeSendCommand();
  });

  floor.on('connect', () => {
    floorReady = true;
    floor.publish('hotel/device/status/floor/floor_03', JSON.stringify({
      device_id: 'floor_03',
      device_type: 'floor',
      status: 'online',
      timestamp: nowIso(),
    }));
    floor.subscribe('hotel/device/command/floor/floor_03', (err) => {
      if (err) {
        clearTimeout(timer);
        failAndExit(`subscribe floor command failed: ${err.message}`);
      } else {
        maybeSendCommand();
      }
    });
  });

  floor.on('message', (topic, message) => {
    if (topic !== 'hotel/device/command/floor/floor_03') {
      return;
    }
    let cmd;
    try {
      cmd = JSON.parse(message.toString());
    } catch (e) {
      clearTimeout(timer);
      failAndExit('floor received non-json command');
      return;
    }
    if (cmd.command_id !== COMMAND_ID || cmd.command_type !== 'floor_reset') {
      return;
    }
    const result = {
      device_id: 'floor_03',
      command_id: cmd.command_id,
      command_type: cmd.command_type,
      status: 'success',
      result: '楼控复位占位执行成功',
      timestamp: nowIso(),
    };
    floor.publish('hotel/device/command/result', JSON.stringify(result), { qos: 1 });
    console.log('📤 floor published floor_reset result');
  });

  front.on('connect', () => {
    frontReady = true;
    front.publish('hotel/device/status/front_desk/front_desk_01', JSON.stringify({
      device_id: 'front_desk_01',
      device_type: 'front_desk',
      status: 'online',
      timestamp: nowIso(),
    }));
    front.subscribe('hotel/device/command/result', (err) => {
      if (err) {
        clearTimeout(timer);
        failAndExit(`subscribe command result failed: ${err.message}`);
      } else {
        maybeSendCommand();
      }
    });
  });

  front.on('message', (_, message) => {
    let payload;
    try {
      payload = JSON.parse(message.toString());
    } catch (_) {
      return;
    }
    if (
      payload.device_id === 'floor_03' &&
      payload.command_id === COMMAND_ID &&
      payload.command_type === 'floor_reset' &&
      payload.status === 'success'
    ) {
      clearTimeout(timer);
      passAndExit('front received floor_reset success result');
    }
  });

  for (const c of [room, floor, front]) {
    c.on('error', (err) => {
      clearTimeout(timer);
      failAndExit(`mqtt client error: ${err.message}`);
    });
  }
}

run();
