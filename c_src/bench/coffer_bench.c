/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer High-Performance Multi-Threaded Benchmarking Engine
 * Measures native pipeline throughput, microsecond latency distributions,
 * and high-contention memory concurrency.
 */

#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <inttypes.h>

#include "hdr_histogram.h"
#include "../fixedpoint/fixed_point.h"
#include "../netting/netting_engine.h"
#include "../merkle/merkle_tree.h"

typedef struct {
    int thread_id;
    uint64_t iterations;
    coffer_c_hdr_t *hdr;
    uint64_t success_count;
    uint64_t failure_count;
} worker_args_t;

static inline uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
}

static void *worker_fixedpoint_netting(void *arg) {
    worker_args_t *w = (worker_args_t *)arg;
    uint8_t leaf_hashes[4][COFFER_SHA256_DIGEST_LENGTH];
    uint8_t root[COFFER_SHA256_DIGEST_LENGTH];

    for (uint64_t i = 0; i < w->iterations; i++) {
        uint64_t start = get_time_ns();

        /* Step 1: Fixed-point arithmetic operations */
        coffer_fp_t a = coffer_fp_from_minor(100000 + (int64_t)(i % 5000), 2);
        coffer_fp_t b = coffer_fp_from_minor(2500, 2);
        coffer_fp_t sum = coffer_fp_add(a, b);
        coffer_fp_t div_res;
        coffer_fp_div(sum, coffer_fp_from_int(100), &div_res);

        /* Step 2: Merkle tree hashing simulation */
        uint8_t payload[32];
        memset(payload, (int)(i & 0xFF), sizeof(payload));
        memcpy(payload, &sum.raw, sizeof(sum.raw) < sizeof(payload) ? sizeof(sum.raw) : sizeof(payload));

        coffer_sha256_hash(payload, sizeof(payload), leaf_hashes[0]);
        coffer_sha256_hash(payload, sizeof(payload), leaf_hashes[1]);
        coffer_sha256_hash(payload, sizeof(payload), leaf_hashes[2]);
        coffer_sha256_hash(payload, sizeof(payload), leaf_hashes[3]);

        coffer_merkle_compute_root(leaf_hashes, 4, root);

        uint64_t elapsed_ns = get_time_ns() - start;
        uint64_t elapsed_us = elapsed_ns / 1000ULL;
        if (elapsed_us == 0) elapsed_us = 1;

        coffer_c_hdr_record(w->hdr, elapsed_us);
        w->success_count++;
    }

    return NULL;
}

static void print_report(const char *title, coffer_c_hdr_t *hdr, double duration_sec, int threads, uint64_t total_ops) {
    double throughput = (double)total_ops / duration_sec;
    printf("\n================================================================================\n");
    printf(" COFFER NATIVE BENCHMARK EXECUTION REPORT: %s\n", title);
    printf("================================================================================\n");
    printf(" Concurrency Threads : %d workers\n", threads);
    printf(" Total Completed Ops : %" PRIu64 " transactions\n", total_ops);
    printf(" Benchmark Wall Time : %.4f seconds\n", duration_sec);
    printf(" Net Throughput      : %.2f ops/second\n", throughput);
    printf("--------------------------------------------------------------------------------\n");
    printf(" Latency Percentiles (Microseconds):\n");
    printf("   p50 (Median)      : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 50.0));
    printf("   p75               : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 75.0));
    printf("   p90               : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 90.0));
    printf("   p95               : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 95.0));
    printf("   p99               : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 99.0));
    printf("   p99.9             : %" PRIu64 " us\n", coffer_c_hdr_percentile(hdr, 99.9));
    printf("   Min Latency       : %" PRIu64 " us\n", hdr->min_microseconds);
    printf("   Max Latency       : %" PRIu64 " us\n", hdr->max_microseconds);
    printf("================================================================================\n\n");
}

int main(int argc, char *argv[]) {
    int threads = 8;
    uint64_t total_iterations = 100000;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-t") == 0 && i + 1 < argc) {
            threads = atoi(argv[++i]);
            if (threads <= 0) threads = 1;
        } else if (strcmp(argv[i], "-n") == 0 && i + 1 < argc) {
            total_iterations = (uint64_t)atoll(argv[++i]);
            if (total_iterations <= 0) total_iterations = 1000;
        }
    }

    printf("Starting Coffer Native Engine Benchmark with %d threads, %" PRIu64 " total iterations...\n",
           threads, total_iterations);

    coffer_c_hdr_t hdr;
    coffer_c_hdr_init(&hdr);

    pthread_t *thread_handles = malloc((size_t)threads * sizeof(pthread_t));
    worker_args_t *args = malloc((size_t)threads * sizeof(worker_args_t));
    if (!thread_handles || !args) {
        fprintf(stderr, "Failed to allocate memory for worker threads.\n");
        return 1;
    }

    uint64_t iters_per_thread = total_iterations / (uint64_t)threads;

    uint64_t start_time = get_time_ns();

    for (int i = 0; i < threads; i++) {
        args[i].thread_id = i;
        args[i].iterations = iters_per_thread;
        args[i].hdr = &hdr;
        args[i].success_count = 0;
        args[i].failure_count = 0;
        pthread_create(&thread_handles[i], NULL, worker_fixedpoint_netting, &args[i]);
    }

    uint64_t total_success = 0;
    for (int i = 0; i < threads; i++) {
        pthread_join(thread_handles[i], NULL);
        total_success += args[i].success_count;
    }

    uint64_t total_time_ns = get_time_ns() - start_time;
    double duration_sec = (double)total_time_ns / 1000000000.0;

    print_report("Fixed-Point Arithmetic and Merkle Commit Engine", &hdr, duration_sec, threads, total_success);

    free(thread_handles);
    free(args);
    coffer_c_hdr_destroy(&hdr);

    return 0;
}
