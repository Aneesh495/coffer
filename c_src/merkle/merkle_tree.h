/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: SHA-256 and Merkle Tree Engine
 */

#ifndef COFFER_MERKLE_TREE_H
#define COFFER_MERKLE_TREE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define COFFER_SHA256_DIGEST_LENGTH 32
#define COFFER_SHA256_HEX_LENGTH 64

typedef struct {
    uint32_t state[8];
    uint64_t count;
    uint8_t buffer[64];
} coffer_sha256_ctx_t;

/* SHA-256 API */
void coffer_sha256_init(coffer_sha256_ctx_t *ctx);
void coffer_sha256_update(coffer_sha256_ctx_t *ctx, const uint8_t *data, size_t len);
void coffer_sha256_final(coffer_sha256_ctx_t *ctx, uint8_t digest[COFFER_SHA256_DIGEST_LENGTH]);
void coffer_sha256_hash(const uint8_t *data, size_t len, uint8_t digest[COFFER_SHA256_DIGEST_LENGTH]);
void coffer_digest_to_hex(const uint8_t digest[COFFER_SHA256_DIGEST_LENGTH], char hex[COFFER_SHA256_HEX_LENGTH + 1]);

/* Merkle Tree API */
bool coffer_merkle_compute_root(const uint8_t leaves[][COFFER_SHA256_DIGEST_LENGTH],
                                size_t leaf_count,
                                uint8_t out_root[COFFER_SHA256_DIGEST_LENGTH]);

#endif /* COFFER_MERKLE_TREE_H */
