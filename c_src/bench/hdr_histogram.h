/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Microsecond HDR Latency Histogram in C
 */

#ifndef COFFER_HDR_HISTOGRAM_H
#define COFFER_HDR_HISTOGRAM_H

#include <stdint.h>
#include <stddef.h>
#include <pthread.h>

#define COFFER_HDR_BUCKETS 64

typedef struct {
    uint64_t counts[COFFER_HDR_BUCKETS];
    uint64_t total_count;
    uint64_t sum_microseconds;
    uint64_t min_microseconds;
    uint64_t max_microseconds;
    pthread_mutex_t lock;
} coffer_c_hdr_t;

void coffer_c_hdr_init(coffer_c_hdr_t *hdr);
void coffer_c_hdr_record(coffer_c_hdr_t *hdr, uint64_t latency_us);
uint64_t coffer_c_hdr_percentile(const coffer_c_hdr_t *hdr, double percentile);
void coffer_c_hdr_destroy(coffer_c_hdr_t *hdr);

#endif /* COFFER_HDR_HISTOGRAM_H */
