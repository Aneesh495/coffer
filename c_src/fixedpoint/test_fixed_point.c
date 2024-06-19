/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Unit Test Suite for C Fixed-Point Arithmetic Engine
 */

#include "fixed_point.h"
#include <stdio.h>
#include <assert.h>
#include <string.h>

int main(void) {
    printf("[TEST] Running C fixed-point unit tests...\n");

    coffer_fp_t a, b;
    bool ok_a = coffer_fp_from_string("1250.50", &a);
    bool ok_b = coffer_fp_from_string("750.25", &b);
    assert(ok_a && ok_b);

    /* Addition */
    coffer_fp_t sum = coffer_fp_add(a, b);
    char buf[64];
    coffer_fp_to_string(sum, buf, sizeof(buf), 2);
    assert(strcmp(buf, "2000.75") == 0);

    /* Subtraction */
    coffer_fp_t diff = coffer_fp_sub(a, b);
    coffer_fp_to_string(diff, buf, sizeof(buf), 2);
    assert(strcmp(buf, "500.25") == 0);

    /* Saturating Subtraction */
    coffer_fp_t sat = coffer_fp_sat_sub(b, a);
    assert(coffer_fp_is_zero(sat));

    /* Division */
    coffer_fp_t quot;
    bool div_ok = coffer_fp_div(a, b, &quot);
    assert(div_ok);

    /* Balance Verification */
    coffer_fp_t debits[2] = { a, b };
    coffer_fp_t credits[1] = { sum };
    assert(coffer_fp_verify_balance(debits, 2, credits, 1));

    printf("[TEST] C fixed-point unit tests passed cleanly.\n");
    return 0;
}
