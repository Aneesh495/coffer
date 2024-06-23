/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: Multilateral Netting and Cycle Cancellation
 */

#ifndef COFFER_NETTING_ENGINE_H
#define COFFER_NETTING_ENGINE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "../fixedpoint/fixed_point.h"

#define COFFER_MAX_NETTING_PARTICIPANTS 256

typedef struct {
    char bic[16];
    coffer_fp_t collateral_capacity;
} coffer_participant_t;

typedef struct {
    int debtor_idx;
    int creditor_idx;
    coffer_fp_t amount;
} coffer_obligation_t;

typedef struct {
    size_t participant_count;
    coffer_participant_t participants[COFFER_MAX_NETTING_PARTICIPANTS];
    coffer_fp_t matrix[COFFER_MAX_NETTING_PARTICIPANTS][COFFER_MAX_NETTING_PARTICIPANTS];
} coffer_netting_matrix_t;

typedef struct {
    coffer_fp_t net_positions[COFFER_MAX_NETTING_PARTICIPANTS];
    coffer_fp_t total_gross_volume;
    coffer_fp_t total_net_volume;
    double liquidity_savings_ratio;
    bool is_balanced;
    bool collateral_adequate;
} coffer_netting_result_t;

/* Netting Engine API */
void coffer_netting_init(coffer_netting_matrix_t *ctx);
int coffer_netting_add_participant(coffer_netting_matrix_t *ctx, const char *bic, coffer_fp_t collateral);
bool coffer_netting_add_obligation(coffer_netting_matrix_t *ctx, int debtor_idx, int creditor_idx, coffer_fp_t amount);
bool coffer_netting_optimize(coffer_netting_matrix_t *ctx, coffer_netting_result_t *out_result);

#endif /* COFFER_NETTING_ENGINE_H */
