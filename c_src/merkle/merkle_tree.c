/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: SHA-256 and Merkle Tree Implementation
 */

#include "merkle_tree.h"
#include <string.h>

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define SIGMA0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define SIGMA1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIGMA_LOWER0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIGMA_LOWER1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static void sha256_transform(uint32_t state[8], const uint8_t data[64]) {
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];
    uint32_t w[64];

    for (int i = 0; i < 16; i++) {
        w[i] = ((uint32_t)data[i * 4] << 24) |
               ((uint32_t)data[i * 4 + 1] << 16) |
               ((uint32_t)data[i * 4 + 2] << 8) |
               ((uint32_t)data[i * 4 + 3]);
    }

    for (int i = 16; i < 64; i++) {
        w[i] = SIGMA_LOWER1(w[i - 2]) + w[i - 7] + SIGMA_LOWER0(w[i - 15]) + w[i - 16];
    }

    for (int i = 0; i < 64; i++) {
        uint32_t t1 = h + SIGMA1(e) + CH(e, f, g) + K[i] + w[i];
        uint32_t t2 = SIGMA0(a) + MAJ(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

void coffer_sha256_init(coffer_sha256_ctx_t *ctx) {
    if (!ctx) return;
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
    ctx->count = 0;
}

void coffer_sha256_update(coffer_sha256_ctx_t *ctx, const uint8_t *data, size_t len) {
    if (!ctx || !data || len == 0) return;

    size_t buffer_idx = (size_t)(ctx->count % 64);
    ctx->count += len;

    for (size_t i = 0; i < len; i++) {
        ctx->buffer[buffer_idx++] = data[i];
        if (buffer_idx == 64) {
            sha256_transform(ctx->state, ctx->buffer);
            buffer_idx = 0;
        }
    }
}

void coffer_sha256_final(coffer_sha256_ctx_t *ctx, uint8_t digest[COFFER_SHA256_DIGEST_LENGTH]) {
    if (!ctx || !digest) return;

    size_t buffer_idx = (size_t)(ctx->count % 64);
    ctx->buffer[buffer_idx++] = 0x80;

    if (buffer_idx > 56) {
        while (buffer_idx < 64) ctx->buffer[buffer_idx++] = 0;
        sha256_transform(ctx->state, ctx->buffer);
        buffer_idx = 0;
    }

    while (buffer_idx < 56) ctx->buffer[buffer_idx++] = 0;

    uint64_t total_bits = ctx->count * 8;
    for (int i = 7; i >= 0; i--) {
        ctx->buffer[56 + i] = (uint8_t)(total_bits & 0xff);
        total_bits >>= 8;
    }

    sha256_transform(ctx->state, ctx->buffer);

    for (int i = 0; i < 8; i++) {
        digest[i * 4] = (uint8_t)((ctx->state[i] >> 24) & 0xff);
        digest[i * 4 + 1] = (uint8_t)((ctx->state[i] >> 16) & 0xff);
        digest[i * 4 + 2] = (uint8_t)((ctx->state[i] >> 8) & 0xff);
        digest[i * 4 + 3] = (uint8_t)(ctx->state[i] & 0xff);
    }
}

void coffer_sha256_hash(const uint8_t *data, size_t len, uint8_t digest[COFFER_SHA256_DIGEST_LENGTH]) {
    coffer_sha256_ctx_t ctx;
    coffer_sha256_init(&ctx);
    coffer_sha256_update(&ctx, data, len);
    coffer_sha256_final(&ctx, digest);
}

void coffer_digest_to_hex(const uint8_t digest[COFFER_SHA256_DIGEST_LENGTH], char hex[COFFER_SHA256_HEX_LENGTH + 1]) {
    static const char hex_chars[] = "0123456789abcdef";
    for (int i = 0; i < COFFER_SHA256_DIGEST_LENGTH; i++) {
        hex[i * 2] = hex_chars[(digest[i] >> 4) & 0xf];
        hex[i * 2 + 1] = hex_chars[digest[i] & 0xf];
    }
    hex[COFFER_SHA256_HEX_LENGTH] = '\0';
}

bool coffer_merkle_compute_root(const uint8_t leaves[][COFFER_SHA256_DIGEST_LENGTH],
                                size_t leaf_count,
                                uint8_t out_root[COFFER_SHA256_DIGEST_LENGTH]) {
    if (!leaves || !out_root || leaf_count == 0) return false;

    if (leaf_count == 1) {
        memcpy(out_root, leaves[0], COFFER_SHA256_DIGEST_LENGTH);
        return true;
    }

    /* Working buffer for current layer */
    uint8_t current[1024][COFFER_SHA256_DIGEST_LENGTH];
    size_t count = leaf_count > 1024 ? 1024 : leaf_count;
    for (size_t i = 0; i < count; i++) {
        memcpy(current[i], leaves[i], COFFER_SHA256_DIGEST_LENGTH);
    }

    while (count > 1) {
        size_t next_count = 0;
        for (size_t i = 0; i < count; i += 2) {
            uint8_t combined[COFFER_SHA256_DIGEST_LENGTH * 2];
            memcpy(combined, current[i], COFFER_SHA256_DIGEST_LENGTH);

            if (i + 1 < count) {
                memcpy(combined + COFFER_SHA256_DIGEST_LENGTH, current[i + 1], COFFER_SHA256_DIGEST_LENGTH);
            } else {
                /* Odd node: duplicate self */
                memcpy(combined + COFFER_SHA256_DIGEST_LENGTH, current[i], COFFER_SHA256_DIGEST_LENGTH);
            }

            coffer_sha256_hash(combined, sizeof(combined), current[next_count++]);
        }
        count = next_count;
    }

    memcpy(out_root, current[0], COFFER_SHA256_DIGEST_LENGTH);
    return true;
}
