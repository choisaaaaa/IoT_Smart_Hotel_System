import logger from '../utils/logger';
import pool, { RowDataPacket } from '../config/database';
import aiButlerService from './ai-butler.service';
import mqttService from './mqtt.service';

const DOWNLINK_TOPIC_PREFIX = 'hotel/device/audio/downlink';

/** 单次下行 PCM 切片（字节）。6144 = 192ms@16k / 96ms@32k，比 4096 报文更少。 */
const DOWNLINK_CHUNK_BYTES = 6144;

/**
 * 匀速：每发一片后，等待 = 本段 PCM 时长的 pacingRatio 倍。默认 1 与实时等长，与固件
 * `GLOBAL_VOICE_PLAY_PACE_PERMILLE=1000` 时喇叭侧「按样本率消费」一致。见 VOICE_DOWNLINK_PACING_RATIO（0.25～2）。
 */
const DOWNLINK_PACING_RATIO_DEFAULT = 1;

function readDownlinkPacingRatio(): number {
  const n = parseFloat(process.env.VOICE_DOWNLINK_PACING_RATIO || String(DOWNLINK_PACING_RATIO_DEFAULT));
  if (isNaN(n) || n < 0.25) {
    return DOWNLINK_PACING_RATIO_DEFAULT;
  }
  if (n > 2) {
    return 2;
  }
  return n;
}

/** 同一设备并发处理上限：1 表示 FIFO 串行（默认），适合低算力嵌入式。 */
const DEVICE_CONCURRENCY = 1;

function readDownlinkSampleRate(): 16000 | 32000 {
  const n = parseInt(process.env.VOICE_DOWNLINK_SAMPLE_RATE || '16000', 10);
  if (n === 32000) {
    return 32000;
  }
  return 16000;
}

function readLeadInMs(): number {
  const n = parseInt(process.env.VOICE_DOWNLINK_LEAD_MS || '200', 10);
  if (isNaN(n) || n < 0) {
    return 200;
  }
  if (n > 800) {
    return 800;
  }
  return n;
}

/** 尾静音：I2S/DMA+功放链路在最后一帧写完后仍有延迟，不垫尾时容易听成「最后几个字被吃掉」 */
function readTrailOutMs(): number {
  const n = parseInt(process.env.VOICE_DOWNLINK_TRAIL_MS || '200', 10);
  if (isNaN(n) || n < 0) {
    return 200;
  }
  if (n > 800) {
    return 800;
  }
  return n;
}

interface PendingUtterance {
  pcm: Buffer;
  /** 上行采样率，用于决定是否下采样到 ASR 16k */
  sampleRate: number;
}

/**
 * 桥接客房 MQTT 上行 PCM（Agent 会话）与 AI 管家（ASR→LLM→TTS），
 * 下行 TTS 默认 16k s16le 与客控固件 `GLOBAL_HAL_AUDIO_SAMPLE_RATE_HZ=16000` 对齐；
 * 可用 VOICE_DOWNLINK_SAMPLE_RATE=32000 回退上采样分片。
 *
 * 关键修复（2026-04 全面优化）：
 *   1. 处理中再次收到 PCM 不再「混入下一段」：当前 utterance 与「正在收音」缓冲分离，
 *      当后端还在做 ASR/LLM/TTS 时收到的新 PCM 会进入新的录音段，eos 只把「当前完成的段」入队。
 *   2. eos 不再被丢弃：每个设备维护一个 FIFO 队列，前一段处理完后自动取下一段。
 *   3. 下行 6144B 切片 + 匀速片间：每片后按「该片时长×VOICE_DOWNLINK_PACING_RATIO」等待（默认同实时，与端上 pace=1000 对齐）。
 *   4. 默认 lead 200ms / trail 200ms：DMA 启动 + 功放上电的时间窗，确保「你」「了」首尾不丢。
 */
class VoiceAgentBridgeService {
  /** 当前正在「采集」的录音段（每设备一个） */
  private currentBuffers = new Map<string, Buffer[]>();
  /** 已完成等待处理的 utterance FIFO（每设备一个队列） */
  private pendingQueues = new Map<string, PendingUtterance[]>();
  /** 本包上行样率，eos 时用于 16k/32k → ASR 的 16k 对齐 */
  private uplinkSampleRate = new Map<string, number>();
  /** 当前正在处理的设备：用于尊重 DEVICE_CONCURRENCY */
  private inflight = new Set<string>();

  /** 前台/后台主动广播：把文本转 TTS 并下发到指定客房设备喇叭播放。 */
  async broadcastTextToDevice(deviceId: string, text: string): Promise<boolean> {
    const t = (text || '').trim();
    if (!deviceId || !t) {
      return false;
    }
    const ok = await this.isApprovedRoomDevice(deviceId);
    if (!ok) {
      logger.warn(`[VoiceAgentBridge] 广播跳过，设备未审核或非客房: ${deviceId}`);
      return false;
    }
    const pcm16 = await aiButlerService.textToSpeechPcmS16k(t).catch(() => Buffer.alloc(0));
    if (pcm16.length < 2) {
      logger.warn(`[VoiceAgentBridge] 广播TTS失败或为空: ${deviceId}`);
      return false;
    }
    await this.sendTtsPcmDownlink(deviceId, pcm16);
    logger.info(`[VoiceAgentBridge] 广播已下发到客房: ${deviceId} text_len=${t.length}`);
    return true;
  }

  /**
   * @param topic hotel/device/audio/uplink/{device_id}
   * @param data JSON：session, pcm_base64, eos, sample_rate, device_id, seq ...
   */
  async handleUplinkMessage(topic: string, data: any): Promise<void> {
    const deviceId =
      (typeof data.device_id === 'string' && data.device_id) ||
      topic.split('/').filter(Boolean).pop() ||
      '';

    if (!deviceId) {
      logger.warn('[VoiceAgentBridge] 缺少 device_id');
      return;
    }

    if (data.session !== 'agent') {
      return;
    }

    const ok = await this.isApprovedRoomDevice(deviceId);
    if (!ok) {
      logger.warn(`[VoiceAgentBridge] 设备未审核或非客房: ${deviceId}`);
      return;
    }

    if (typeof data.sample_rate === 'number' && data.sample_rate > 0) {
      this.uplinkSampleRate.set(deviceId, data.sample_rate);
    }

    if (data.eos === true) {
      this.enqueueCurrentAsUtterance(deviceId);
      void this.tryDrainQueue(deviceId);
      return;
    }

    if (!data.pcm_base64 || typeof data.pcm_base64 !== 'string') {
      return;
    }

    let pcm: Buffer;
    try {
      pcm = Buffer.from(data.pcm_base64, 'base64');
    } catch {
      return;
    }
    if (pcm.length === 0) {
      return;
    }

    if (!this.currentBuffers.has(deviceId)) {
      this.currentBuffers.set(deviceId, []);
    }
    this.currentBuffers.get(deviceId)!.push(pcm);
  }

  /** 把「当前正在收音」的缓冲合并成一个 utterance 入队 */
  private enqueueCurrentAsUtterance(deviceId: string): void {
    const chunks = this.currentBuffers.get(deviceId) || [];
    this.currentBuffers.set(deviceId, []);
    if (chunks.length === 0) {
      logger.info(`[VoiceAgentBridge] eos 时无 PCM 可入队: ${deviceId}`);
      return;
    }
    const merged = Buffer.concat(chunks);
    if (merged.length < 4) {
      logger.info(`[VoiceAgentBridge] eos 时 PCM 过短: ${deviceId} len=${merged.length}`);
      return;
    }
    const sr = this.uplinkSampleRate.get(deviceId) ?? 32000;
    const queue = this.pendingQueues.get(deviceId) || [];
    queue.push({ pcm: merged, sampleRate: sr });
    this.pendingQueues.set(deviceId, queue);
    logger.info(
      `[VoiceAgentBridge] eos 入队 device=${deviceId} pcmBytes=${merged.length} sr=${sr} 队列长度=${queue.length}`
    );
  }

  private async tryDrainQueue(deviceId: string): Promise<void> {
    if (this.inflight.size >= DEVICE_CONCURRENCY && this.inflight.has(deviceId)) {
      return;
    }
    if (this.inflight.has(deviceId)) {
      return;
    }
    const queue = this.pendingQueues.get(deviceId);
    if (!queue || queue.length === 0) {
      return;
    }
    const item = queue.shift()!;
    this.inflight.add(deviceId);
    try {
      await this.processUtterance(deviceId, item);
    } catch (e: any) {
      logger.error(`[VoiceAgentBridge] 处理失败 device=${deviceId}: ${e.message}`);
    } finally {
      this.inflight.delete(deviceId);
      if (queue.length > 0) {
        // 异步触发下一段，避免在 finally 内深递归
        setImmediate(() => {
          void this.tryDrainQueue(deviceId);
        });
      }
    }
  }

  private async isApprovedRoomDevice(deviceId: string): Promise<boolean> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT device_id FROM devices WHERE device_id = ? AND device_type = ? AND audit_status = ?',
        [deviceId, 'room', 'approved']
      );
      return rows.length > 0;
    } catch (e: any) {
      logger.error('[VoiceAgentBridge] DB 查询失败:', e.message);
      return false;
    }
  }

  /** 32k s16le → 16k s16le：每两个采样取一个 */
  private downsample32kTo16k(pcm32: Buffer): Buffer {
    if (pcm32.length < 4 || pcm32.length % 2 !== 0) {
      return Buffer.alloc(0);
    }
    const inSamples = pcm32.length / 2;
    const outSamples = Math.floor(inSamples / 2);
    const out = Buffer.alloc(outSamples * 2);
    for (let i = 0; i < outSamples; i++) {
      out.writeInt16LE(pcm32.readInt16LE(i * 4), i * 2);
    }
    return out;
  }

  /** 在整段 s16le mono 前拼接静音，供喇叭通道建立后再播真实 TTS，避免只听到字尾。 */
  private prependSilencePcm(pcm: Buffer, leadMs: number, sampleRate: number): Buffer {
    if (leadMs <= 0 || pcm.length === 0) {
      return pcm;
    }
    const samples = Math.floor((sampleRate * leadMs) / 1000);
    if (samples <= 0) {
      return pcm;
    }
    const pad = Buffer.alloc(samples * 2, 0);
    return Buffer.concat([pad, pcm]);
  }

  private appendSilencePcm(pcm: Buffer, trailMs: number, sampleRate: number): Buffer {
    if (trailMs <= 0 || pcm.length === 0) {
      return pcm;
    }
    const samples = Math.floor((sampleRate * trailMs) / 1000);
    if (samples <= 0) {
      return pcm;
    }
    const pad = Buffer.alloc(samples * 2, 0);
    return Buffer.concat([pcm, pad]);
  }

  /** 16k s16le → 32k s16le：每采样重复一次 */
  private upsample16kTo32k(pcm16: Buffer): Buffer {
    if (pcm16.length < 2 || pcm16.length % 2 !== 0) {
      return Buffer.alloc(0);
    }
    const inSamples = pcm16.length / 2;
    const out = Buffer.alloc(inSamples * 4);
    for (let i = 0; i < inSamples; i++) {
      const s = pcm16.readInt16LE(i * 2);
      out.writeInt16LE(s, i * 4);
      out.writeInt16LE(s, i * 4 + 2);
    }
    return out;
  }

  /** 静音检测（避免把没说话的录音也送进 ASR 浪费一次大模型调用） */
  private isLikelySilence(pcm16k: Buffer): boolean {
    if (pcm16k.length < 2) {
      return true;
    }
    const samples = pcm16k.length / 2;
    let peak = 0;
    let sumAbs = 0;
    // 抽样判断（每 8 个采样取 1 个），1s 16k 数据 16000/8=2000 次循环，足够快
    for (let i = 0; i < samples; i += 8) {
      const v = pcm16k.readInt16LE(i * 2);
      const a = v < 0 ? -v : v;
      if (a > peak) {
        peak = a;
      }
      sumAbs += a;
    }
    const checked = Math.max(1, Math.floor(samples / 8));
    const avg = sumAbs / checked;
    // 经验阈值：peak < 600 (≈ -35dBFS) 且 avg < 120 视为静音
    if (peak < 600 && avg < 120) {
      logger.warn(`[VoiceAgentBridge] 检测到几乎静音 peak=${peak} avg=${Math.round(avg)}，跳过 ASR`);
      return true;
    }
    return false;
  }

  private async processUtterance(deviceId: string, item: PendingUtterance): Promise<void> {
    const upSr = item.sampleRate;
    let pcm16k: Buffer;
    if (upSr === 16000) {
      if (item.pcm.length < 2 || item.pcm.length % 2 !== 0) {
        logger.warn(`[VoiceAgentBridge] 16k 上行长度无效: device=${deviceId} len=${item.pcm.length}`);
        return;
      }
      pcm16k = item.pcm;
      logger.info(`[VoiceAgentBridge] 上行 16k PCM 直送 ASR, device=${deviceId} bytes=${pcm16k.length}`);
    } else {
      pcm16k = this.downsample32kTo16k(item.pcm);
      if (pcm16k.length < 4) {
        logger.warn(`[VoiceAgentBridge] 下采样后长度过短: ${deviceId}`);
        return;
      }
    }

    if (this.isLikelySilence(pcm16k)) {
      // 直接给一段简短的「没听清」回执，避免用户傻等
      const hint = '抱歉，我没有听清楚，请再说一次。';
      const buf = await aiButlerService.textToSpeechPcmS16k(hint).catch(() => Buffer.alloc(0));
      if (buf.length > 0) {
        await this.sendTtsPcmDownlink(deviceId, buf);
      }
      return;
    }

    const audioData = pcm16k.toString('base64');
    const res = await aiButlerService.processRequest({
      roomId: deviceId,
      audioData,
      text: undefined,
      sessionId: `agent_mqtt_${deviceId}_${Date.now()}`,
      hardwarePcmTts: true
    });

    const replyText = res.text ?? '';
    if (res.recognizedText) {
      logger.info(
        `[VoiceAgentBridge] ASR device=${deviceId} ${JSON.stringify(res.recognizedText)}`
      );
    }
    logger.info(`[VoiceAgentBridge] 回复 device=${deviceId} ${JSON.stringify(replyText)}`);

    const pcmB64 = res.audioPcmBase64;
    if (!pcmB64 || !pcmB64.length) {
      logger.warn(
        `[VoiceAgentBridge] 无 TTS PCM 输出 device=${deviceId} text_len=${(res.text || '').length}`
      );
      return;
    }

    const pcm16 = Buffer.from(pcmB64, 'base64');
    if (pcm16.length < 2) {
      return;
    }
    await this.sendTtsPcmDownlink(deviceId, pcm16);
  }

  /** 把 16k s16le mono PCM 加首尾静音、按需上采样并以流式分片下发 */
  private async sendTtsPcmDownlink(deviceId: string, pcm16: Buffer): Promise<void> {
    const downSr = readDownlinkSampleRate();
    const leadMs = readLeadInMs();
    const trailMs = readTrailOutMs();

    let outPcm: Buffer;
    if (downSr === 32000) {
      outPcm = this.upsample16kTo32k(pcm16);
      if (outPcm.length < 2) {
        return;
      }
      outPcm = this.prependSilencePcm(outPcm, leadMs, 32000);
      outPcm = this.appendSilencePcm(outPcm, trailMs, 32000);
      logger.info(
        `[VoiceAgentBridge] 下行 32k s16le 加首尾静音: lead=${leadMs}ms trail=${trailMs}ms total=${outPcm.length}B`
      );
    } else {
      outPcm = this.prependSilencePcm(pcm16, leadMs, 16000);
      outPcm = this.appendSilencePcm(outPcm, trailMs, 16000);
      logger.info(
        `[VoiceAgentBridge] 下行 16k s16le 加首尾静音: lead=${leadMs}ms trail=${trailMs}ms total=${outPcm.length}B`
      );
    }

    await this.publishDownlinkChunks(deviceId, outPcm, downSr);
  }

  private async publishDownlinkChunks(
    deviceId: string,
    pcm: Buffer,
    outSampleRate: 16000 | 32000
  ): Promise<void> {
    const topic = `${DOWNLINK_TOPIC_PREFIX}/${deviceId}`;
    const pacingRatio = readDownlinkPacingRatio();
    let off = 0;
    let seq = 0;

    while (off < pcm.length) {
      const end = Math.min(off + DOWNLINK_CHUNK_BYTES, pcm.length);
      const chunk = pcm.subarray(off, end);
      seq += 1;

      // 流式音频务必使用 QoS 0：QoS 1 的逐包 ACK 会让大段 TTS 退化成几秒的卡顿
      await mqttService.publish(
        topic,
        {
          format: 'pcm_s16le',
          sample_rate: outSampleRate,
          seq,
          pcm_base64: chunk.toString('base64')
        },
        0
      );

      off = end;
      if (off >= pcm.length) {
        break;
      }
      const chunkMs = (chunk.length / 2 / outSampleRate) * 1000;
      const waitMs = Math.max(1, Math.floor(chunkMs * pacingRatio));
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
    logger.info(
      `[VoiceAgentBridge] TTS 已匀速流式下发(QoS 0) pacing=${pacingRatio} device=${deviceId} 块数=${seq} 总=${pcm.length}B @${outSampleRate}Hz`
    );
  }
}

let inst: VoiceAgentBridgeService | null = null;
export function getVoiceAgentBridge(): VoiceAgentBridgeService {
  if (!inst) {
    inst = new VoiceAgentBridgeService();
  }
  return inst;
}

export default VoiceAgentBridgeService;
