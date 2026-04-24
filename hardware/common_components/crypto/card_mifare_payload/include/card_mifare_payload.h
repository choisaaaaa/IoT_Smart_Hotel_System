#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 房卡扇区应用层保护格式（与 RC522 / MIFARE Classic 1K 16 字节块对齐）：
 *
 * - 依据 NXP《MIFARE Classic》系列说明：用户数据块内为明文比特；射频链路 Crypto1
 *   仅保护读写到读卡器之间的会话，不替代应用层保密。因此扇区内采用应用层对称加密。
 * - 选用 AES-128-ECB：单块 16 字节，与 Classic 块长一致，无需跨块 IV 管理。
 *   实现：ESP-IDF v6 使用 PSA Crypto（Mbed TLS v4 已移除 mbedtls_aes_* 旧 API）。
 * - 客房卡：明文字符串「ROOM:<房号>」；特权卡（与后端 card_type 一致）：「TYPE:<master|floor|staff|emergency>」等。
 *   单块 16 字节：标签+值总长（含冒号）须 ≤15 字节，再 PKCS#7 填充后 AES-128-ECB。
 *
 * 密钥：16 字节 AES-128。开发默认见 global_config.h 的 GLOBAL_CARD_AES128_HEX_DEFAULT；
 * 生产环境请写入 NVS 键 HotelCard_AES128Hex（32 位十六进制），前台与客房必须一致。
 */

#define CARD_MIFARE_ROOM_PREFIX "ROOM:"

bool card_mifare_parse_hex_key(const char *hex32, uint8_t key_out[16]);

/** 通用「TAG:VALUE」加密（如 ROOM:301、TYPE:master）。tag/value 均非空且 strlen(tag)+1+strlen(value) ≤ 15。 */
bool card_mifare_encrypt_tag_value_payload(const char *tag, const char *value, const uint8_t key[16], uint8_t block16[16]);

bool card_mifare_encrypt_room_payload(const char *room_id, const uint8_t key[16], uint8_t block16[16]);

bool card_mifare_parse_sector_room(const uint8_t block16[16], const uint8_t key[16], char *room_out,
                                   size_t room_out_sz);

#ifdef __cplusplus
}
#endif
