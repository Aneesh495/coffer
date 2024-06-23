/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: Multilateral Netting Implementation
 */

#include "netting_engine.h"
#include <string.h>

void coffer_netting_init(coffer_netting_matrix_t *ctx) {
    if (!ctx) return;
    ctx->participant_count = 0;
    for (size_t i = 0; i < COFFER_MAX_NETTING_PARTICIPANTS; i++) {
        for (size_t j = 0; j < COFFER_MAX_NETTING_PARTICIPANTS; j++) {
            ctx->matrix[i][j].raw = 0;
        }
    }
}

int coffer_netting_add_participant(coffer_netting_matrix_t *ctx, const char *bic, coffer_fp_t collateral) {
    if (!ctx || !bic || ctx->participant_count >= COFFER_MAX_NETTING_PARTICIPANTS) return -1;

    size_t idx = ctx->participant_count++;
    strncpy(ctx->participants[idx].bic, bic, sizeof(ctx->participants[idx].bic) - 1);
    ctx->participants[idx].bic[sizeof(ctx->participants[idx].bic) - 1] = '\0';
    ctx->participants[idx].collateral_capacity = collateral;

    return (int)idx;
}

bool coffer_netting_add_obligation(coffer_netting_matrix_t *ctx, int debtor_idx, int creditor_idx, coffer_fp_t amount) {
    if (!ctx) return false;
    if (debtor_idx < 0 || (size_t)debtor_idx >= ctx->participant_count) return false;
    if (creditor_idx < 0 || (size_t)creditor_idx >= ctx->participant_count) return false;
    if (debtor_idx == creditor_idx) return false;

    ctx->matrix[debtor_idx][creditor_idx] = coffer_fp_add(ctx->matrix[debtor_idx][creditor_idx], amount);
    return true;
}

bool coffer_netting_optimize(coffer_netting_matrix_t *ctx, coffer_netting_result_t *out_result) {
    if (!ctx || !out_result) return false;

    size_t n = ctx->participant_count;
    coffer_fp_t gross_total = { .raw = 0 };
    coffer_fp_t net_total = { .raw = 0 };

    /* 1. Calculate Gross Volumes */
    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            gross_total = coffer_fp_add(gross_total, ctx->matrix[i][j]);
        }
    }

    /* 2. Compute Net Positions: Net[i] = Inflow[i] - Outflow[i] */
    coffer_fp_t sum_debits = { .raw = 0 };
    coffer_fp_t sum_credits = { .raw = 0 };
    bool collateral_ok = true;

    for (size_t i = 0; i < n; i++) {
        coffer_fp_t inflow = { .raw = 0 };
        coffer_fp_t outflow = { .raw = 0 };

        for (size_t j = 0; j < n; j++) {
            inflow = coffer_fp_add(inflow, ctx->matrix[j][i]);
            outflow = coffer_fp_add(outflow, ctx->matrix[i][j]);
        }

        coffer_fp_t net = coffer_fp_sub(inflow, outflow);
        out_result->net_positions[i] = net;

        if (coffer_fp_is_negative(net)) {
            coffer_fp_t net_debt = coffer_fp_abs(net);
            sum_debits = coffer_fp_add(sum_debits, net_debt);
            net_total = coffer_fp_add(net_total, net_debt);

            /* Check collateral */
            if (coffer_fp_cmp(net_debt, ctx->participants[i].collateral_capacity) > 0) {
                collateral_ok = false;
            }
        } else if (coffer_fp_is_positive(net)) {
            sum_credits = coffer_fp_add(sum_credits, net);
        }
    }

    /* 3. Invariant check: Total net debits must equal total net credits */
    bool balanced = (coffer_fp_cmp(sum_debits, sum_credits) == 0);

    out_result->total_gross_volume = gross_total;
    out_result->total_net_volume = net_total;
    out_result->is_balanced = balanced;
    out_result->collateral_adequate = collateral_ok;

    double g_val = (double)(gross_total.raw / COFFER_FP_SCALE_FACTOR);
    double n_val = (double)(net_total.raw / COFFER_FP_SCALE_FACTOR);
    out_result->liquidity_savings_ratio = g_val > 0.0 ? (1.0 - (n_val / g_val)) * 100.0 : 0.0;

    return balanced;
}
