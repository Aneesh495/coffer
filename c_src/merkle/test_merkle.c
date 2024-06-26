/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Unit Test Suite for C SHA-256 and Merkle Tree Engine
 */

#include "merkle_tree.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

int main(void) {
    printf("[TEST] Running C SHA-256 and Merkle tree unit tests...\n");

    /* Test standard NIST SHA-256 vector for "abc" */
    /* Expected: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad */
    uint8_t digest[COFFER_SHA256_DIGEST_LENGTH];
    coffer_sha256_hash((const uint8_t *)"abc", 3, digest);

    char hex[COFFER_SHA256_HEX_LENGTH + 1];
    coffer_digest_to_hex(digest, hex);
    assert(strcmp(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") == 0);

    /* Test Merkle Root with 3 leaves */
    uint8_t leaves[3][COFFER_SHA256_DIGEST_LENGTH];
    coffer_sha256_hash((const uint8_t *)"leaf_01", 7, leaves[0]);
    coffer_sha256_hash((const uint8_t *)"leaf_02", 7, leaves[1]);
    coffer_sha256_hash((const uint8_t *)"leaf_03", 7, leaves[2]);

    uint8_t root[COFFER_SHA256_DIGEST_LENGTH];
    bool ok = coffer_merkle_compute_root((const uint8_t (*)[32])leaves, 3, root);
    assert(ok);

    char root_hex[COFFER_SHA256_HEX_LENGTH + 1];
    coffer_digest_to_hex(root, root_hex);
    assert(strlen(root_hex) == 64);

    printf("[TEST] C SHA-256 and Merkle tree unit tests passed cleanly.\n");
    return 0;
}
