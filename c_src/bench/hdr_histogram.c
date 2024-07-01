/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Microsecond HDR Latency Histogram Implementation in C
 */

#include "hdr_histogram.h"
#include <string.h>

static const uint64_t BUCKET_BOUNDS[COFFER_HDR_BUCKETS] = {
    10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
    150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000,
    1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000,
    15000, 20000, 25000, 30000, 40000, 50000, 75000, 100000,
    150000, 200000, 250000, 300000, 400000, 500000, 750000, 1000000,
    1500000, 2000000, 2500000, 3000000, 4000000, 5000000, 10000000,
    15000000, 20000000, 30000000, 60000000, 120000000, 300000000, 600000000
};

void coffer_c_hdr_init(coffer_c_hdr_t *hdr) {
    if (!hdr) return;
    memset(hdr->counts, 0, sizeof(hdr->counts));
    hdr->total_count = 0;
    hdr->sum_microseconds = 0;
    hdr->min_microseconds = UINT64_MAX;
    hdr->max_microseconds = 0;
    pthread_mutex_init(&hdr->lock, NULL);
}

void coffer_c_hdr_record(coffer_c_hdr_t *hdr, uint64_t latency_us) {
    if (!hdr) return;
    pthread_mutex_lock(&hdr->lock);

    hdr->total_count++;
    hdr->sum_microseconds += latency_us;
    if (latency_us < hdr->min_microseconds) hdr->min_microseconds = latency_us;
    if (latency_us > hdr->max_microseconds) hdr->max_microseconds = latency_us;

    int placed = 0;
    for (int i = 0; i < COFFER_HDR_BUCKETS; i++) {
        if (latency_us <= BUCKET_BOUNDS[i]) {
            hdr->counts[i]++;
            placed = 1;
            break;
        }
    }
    if (!placed) {
        hdr->counts[COFFER_HDR_BUCKETS - 1]++;
    }

    pthread_mutex_unlock(&hdr->lock);
}

uint64_t coffer_c_hdr_percentile(const coffer_c_hdr_t *hdr, double percentile) {
    if (!hdr || hdr->total_count == 0) return 0;

    double threshold = (double)hdr->total_count * (percentile / 100.0);
    uint64_t accumulated = 0;

    for (int i = 0; i < COFFER_HDR_BUCKETS; i++) {
        accumulated += hdr->counts[i];
        if ((double)accumulated >= threshold) {
            return BUCKET_BOUNDS[i];
        }
    }

    return hdr->max_microseconds;
}

void coffer_c_hdr_destroy(coffer_c_hdr_t *hdr) {
    if (hdr) {
        pthread_mutex_destroy(&hdr->lock);
    }
}
