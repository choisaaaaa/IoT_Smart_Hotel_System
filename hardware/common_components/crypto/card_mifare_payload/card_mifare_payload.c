#include "card_mifare_payload.h"
#include "psa/crypto.h"
#include <string.h>

/** ESP-IDF v6 / Mbed TLS v4 已移除 mbedtls/aes.h，此处用 PSA AES-128-ECB（与单块 16 字节载荷一致）。 */
static bool aes128_ecb_block(const uint8_t key[16], const uint8_t in16[16], uint8_t out16[16], bool encrypt)
{
    psa_key_attributes_t attr = PSA_KEY_ATTRIBUTES_INIT;
    psa_set_key_usage_flags(&attr, encrypt ? PSA_KEY_USAGE_ENCRYPT : PSA_KEY_USAGE_DECRYPT);
    psa_set_key_lifetime(&attr, PSA_KEY_LIFETIME_VOLATILE);
    psa_set_key_algorithm(&attr, PSA_ALG_ECB_NO_PADDING);
    psa_set_key_type(&attr, PSA_KEY_TYPE_AES);
    psa_set_key_bits(&attr, 128);

    psa_key_id_t kid = 0;
    psa_status_t st = psa_import_key(&attr, key, 16, &kid);
    psa_reset_key_attributes(&attr);
    if (st != PSA_SUCCESS) {
        return false;
    }

    size_t olen = 0;
    if (encrypt) {
        st = psa_cipher_encrypt(kid, PSA_ALG_ECB_NO_PADDING, in16, 16, out16, 16, &olen);
    } else {
        st = psa_cipher_decrypt(kid, PSA_ALG_ECB_NO_PADDING, in16, 16, out16, 16, &olen);
    }
    (void)psa_destroy_key(kid);
    return (st == PSA_SUCCESS && olen == 16);
}

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

bool card_mifare_parse_hex_key(const char *hex32, uint8_t key_out[16]) {
    if (hex32 == NULL || key_out == NULL) {
        return false;
    }
    if (strlen(hex32) != 32) {
        return false;
    }
    for (int i = 0; i < 16; i++) {
        int hi = hex_nibble(hex32[i * 2]);
        int lo = hex_nibble(hex32[i * 2 + 1]);
        if (hi < 0 || lo < 0) {
            return false;
        }
        key_out[i] = (uint8_t)((hi << 4) | lo);
    }
    return true;
}

static bool pkcs7_pad(const uint8_t *src, size_t src_len, uint8_t out16[16]) {
    if (src_len > 15 || src_len == 0) {
        return false;
    }
    uint8_t pad = (uint8_t)(16 - src_len);
    if (pad == 0 || pad > 16) {
        return false;
    }
    memcpy(out16, src, src_len);
    for (size_t i = src_len; i < 16; i++) {
        out16[i] = pad;
    }
    return true;
}

static bool pkcs7_unpad(const uint8_t in16[16], uint8_t *out_plain, size_t *out_len, size_t out_cap) {
    uint8_t pad = in16[15];
    if (pad == 0 || pad > 16) {
        return false;
    }
    for (int i = 16 - pad; i < 16; i++) {
        if (in16[i] != pad) {
            return false;
        }
    }
    size_t body = (size_t)(16 - pad);
    if (body == 0 || body > out_cap) {
        return false;
    }
    memcpy(out_plain, in16, body);
    *out_len = body;
    return true;
}

bool card_mifare_encrypt_room_payload(const char *room_id, uint32_t expire_time, const char *card_level, const uint8_t key[16], uint8_t block16[16]) {
    if (room_id == NULL || key == NULL || block16 == NULL) {
        return false;
    }
    if (room_id[0] == '\0') {
        return false;
    }
    if (strlen(room_id) > 5) { // Ensure fits in 6 bytes with null
        return false;
    }

    uint8_t plain[16] = {0};
    plain[0] = 'H';
    plain[1] = 'C';
    strncpy((char *)&plain[2], room_id, 6);
    
    plain[8] = (uint8_t)(expire_time & 0xFF);
    plain[9] = (uint8_t)((expire_time >> 8) & 0xFF);
    plain[10] = (uint8_t)((expire_time >> 16) & 0xFF);
    plain[11] = (uint8_t)((expire_time >> 24) & 0xFF);
    
    uint8_t level_enum = 0;
    if (card_level) {
        if (strcmp(card_level, "silver") == 0) level_enum = 1;
        else if (strcmp(card_level, "gold") == 0) level_enum = 2;
        else if (strcmp(card_level, "platinum") == 0) level_enum = 3;
        else if (strcmp(card_level, "diamond") == 0) level_enum = 4;
    }
    plain[12] = level_enum;

    return aes128_ecb_block(key, plain, block16, true);
}

static bool parse_room_prefix(const char *plain, size_t len, char *room_out, size_t room_out_sz) {
    const char *p = plain;
    size_t prefix_len = strlen(CARD_MIFARE_ROOM_PREFIX);
    if (len < prefix_len || strncmp(p, CARD_MIFARE_ROOM_PREFIX, prefix_len) != 0) {
        return false;
    }
    size_t rid_len = len - prefix_len;
    if (rid_len == 0 || rid_len >= room_out_sz) {
        return false;
    }
    memcpy(room_out, p + prefix_len, rid_len);
    room_out[rid_len] = '\0';
    return room_out[0] != '\0';
}

bool card_mifare_parse_sector_room(const uint8_t block16[16], const uint8_t key[16], char *room_out,
                                   size_t room_out_sz, uint32_t *expire_out, char *level_out, size_t level_out_sz) {
    if (block16 == NULL || key == NULL || room_out == NULL || room_out_sz == 0) {
        return false;
    }

    char as_text[17];
    memcpy(as_text, block16, 16);
    as_text[16] = '\0';
    if (strncmp(as_text, CARD_MIFARE_ROOM_PREFIX, strlen(CARD_MIFARE_ROOM_PREFIX)) == 0) {
        if (expire_out) *expire_out = 0;
        if (level_out && level_out_sz > 0) {
            strncpy(level_out, "guest", level_out_sz - 1);
            level_out[level_out_sz - 1] = '\0';
        }
        return parse_room_prefix(as_text, strnlen(as_text, 16), room_out, room_out_sz);
    }

    uint8_t plain[16];
    if (!aes128_ecb_block(key, block16, plain, false)) {
        return false;
    }

    if (plain[0] == 'H' && plain[1] == 'C') {
        size_t rlen = strnlen((char *)&plain[2], 6);
        if (rlen >= room_out_sz) return false;
        memcpy(room_out, &plain[2], rlen);
        room_out[rlen] = '\0';

        if (expire_out) {
            *expire_out = (uint32_t)plain[8] | ((uint32_t)plain[9] << 8) |
                          ((uint32_t)plain[10] << 16) | ((uint32_t)plain[11] << 24);
        }
        if (level_out && level_out_sz > 0) {
            const char *ls = "guest";
            if (plain[12] == 1) ls = "silver";
            else if (plain[12] == 2) ls = "gold";
            else if (plain[12] == 3) ls = "platinum";
            else if (plain[12] == 4) ls = "diamond";
            strncpy(level_out, ls, level_out_sz - 1);
            level_out[level_out_sz - 1] = '\0';
        }
        return true;
    }

    size_t body_len = 0;
    uint8_t unpadded[16];
    if (!pkcs7_unpad(plain, unpadded, &body_len, sizeof(unpadded))) {
        return false;
    }
    if (expire_out) *expire_out = 0;
    if (level_out && level_out_sz > 0) {
        strncpy(level_out, "guest", level_out_sz - 1);
        level_out[level_out_sz - 1] = '\0';
    }
    return parse_room_prefix((const char *)unpadded, body_len, room_out, room_out_sz);
}
