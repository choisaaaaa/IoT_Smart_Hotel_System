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

bool card_mifare_encrypt_tag_value_payload(const char *tag, const char *value, const uint8_t key[16], uint8_t block16[16]) {
    if (tag == NULL || value == NULL || key == NULL || block16 == NULL) {
        return false;
    }
    if (tag[0] == '\0' || value[0] == '\0') {
        return false;
    }
    size_t tl = strlen(tag);
    size_t vl = strlen(value);
    if (tl + 1 + vl > 15) {
        return false;
    }

    char inner[20];
    int n = snprintf(inner, sizeof(inner), "%s:%s", tag, value);
    if (n <= 0 || n >= (int)sizeof(inner)) {
        return false;
    }

    uint8_t padded[16];
    if (!pkcs7_pad((const uint8_t *)inner, (size_t)n, padded)) {
        return false;
    }

    return aes128_ecb_block(key, padded, block16, true);
}

bool card_mifare_encrypt_room_payload(const char *room_id, const uint8_t key[16], uint8_t block16[16]) {
    if (room_id == NULL || key == NULL || block16 == NULL) {
        return false;
    }
    if (room_id[0] == '\0') {
        return false;
    }
    if (strlen(room_id) > 10) {
        return false;
    }
    return card_mifare_encrypt_tag_value_payload("ROOM", room_id, key, block16);
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
                                   size_t room_out_sz) {
    if (block16 == NULL || key == NULL || room_out == NULL || room_out_sz == 0) {
        return false;
    }

    char as_text[17];
    memcpy(as_text, block16, 16);
    as_text[16] = '\0';
    if (strncmp(as_text, CARD_MIFARE_ROOM_PREFIX, strlen(CARD_MIFARE_ROOM_PREFIX)) == 0) {
        return parse_room_prefix(as_text, strnlen(as_text, 16), room_out, room_out_sz);
    }

    uint8_t plain[16];
    if (!aes128_ecb_block(key, block16, plain, false)) {
        return false;
    }

    size_t body_len = 0;
    uint8_t unpadded[16];
    if (!pkcs7_unpad(plain, unpadded, &body_len, sizeof(unpadded))) {
        return false;
    }
    return parse_room_prefix((const char *)unpadded, body_len, room_out, room_out_sz);
}
