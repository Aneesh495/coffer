/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Unit Test Suite for C Multilateral Netting Engine
 */

#include "netting_engine.h"
#include <stdio.h>
#include <assert.h>

int main(void) {
    printf("[TEST] Running C multilateral netting unit tests...\n");

    coffer_netting_matrix_t ctx;
    coffer_netting_init(&ctx);

    coffer_fp_t col = coffer_fp_from_int(1000000);
    int p_chase = coffer_netting_add_participant(&ctx, "CHASUS33XXX", col);
    int p_bofa = coffer_netting_add_participant(&ctx, "BOFAUS3NXXX", col);
    int p_citi = coffer_netting_add_participant(&ctx, "CITIUS33XXX", col);

    assert(p_chase == 0 && p_bofa == 1 && p_citi == 2);

    /* Chase owes BofA $100M */
    coffer_netting_add_obligation(&ctx, p_chase, p_bofa, coffer_fp_from_int(100));
    /* BofA owes Citi $80M */
    coffer_netting_add_obligation(&ctx, p_bofa, p_citi, coffer_fp_from_int(80));
    /* Citi owes Chase $70M */
    coffer_netting_add_obligation(&ctx, p_citi, p_chase, coffer_fp_from_int(70));

    coffer_netting_result_t res;
    bool ok = coffer_netting_optimize(&ctx, &res);
    assert(ok);
    assert(res.is_balanced);
    assert(res.collateral_adequate);

    /* Gross should be $250M */
    assert(res.total_gross_volume.raw == coffer_fp_from_int(250).raw);
    /* Net settlement volume should be $30M */
    assert(res.total_net_volume.raw == coffer_fp_from_int(30).raw);
    /* Liquidity savings ratio should be 88% */
    assert(res.liquidity_savings_ratio >= 85.0);

    printf("[TEST] C multilateral netting unit tests passed cleanly.\n");
    return 0;
}
