/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: 128-Bit Fixed-Point Arithmetic
 * Implements high-assurance scaled decimal arithmetic with 18 decimal places,
 * saturation bounds, Bankers rounding (Half-Even), and vectorized balance proofs.
 */

#ifndef COFFER_FIXED_POINT_H
#define COFFER_FIXED_POINT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define COFFER_FP_SCALE 18
#define COFFER_FP_SCALE_FACTOR ((__int128_t)1000000000000000000LL)

typedef struct {
    __int128_t raw;
} coffer_fp_t;

/* Constructors and Parsers */
coffer_fp_t coffer_fp_from_int(int64_t integer_val);
coffer_fp_t coffer_fp_from_minor(int64_t minor_units, int minor_scale);
bool coffer_fp_from_string(const char *str, coffer_fp_t *out);
void coffer_fp_to_string(coffer_fp_t val, char *buffer, size_t buffer_size, int decimals);
int64_t coffer_fp_to_minor(coffer_fp_t val, int minor_scale);

/* Arithmetic Operations */
coffer_fp_t coffer_fp_add(coffer_fp_t a, coffer_fp_t b);
coffer_fp_t coffer_fp_sub(coffer_fp_t a, coffer_fp_t b);
coffer_fp_t coffer_fp_mul(coffer_fp_t a, coffer_fp_t b);
bool coffer_fp_div(coffer_fp_t a, coffer_fp_t b, coffer_fp_t *out);
coffer_fp_t coffer_fp_abs(coffer_fp_t a);

/* Saturation Arithmetic */
coffer_fp_t coffer_fp_sat_sub(coffer_fp_t a, coffer_fp_t b);

/* Predicates and Comparisons */
int coffer_fp_cmp(coffer_fp_t a, coffer_fp_t b);
bool coffer_fp_is_zero(coffer_fp_t a);
bool coffer_fp_is_positive(coffer_fp_t a);
bool coffer_fp_is_negative(coffer_fp_t a);

/* Vectorized Double-Entry Balance Verification */
bool coffer_fp_verify_balance(const coffer_fp_t *debits, size_t debit_count,
                              const coffer_fp_t *credits, size_t credit_count);

#endif /* COFFER_FIXED_POINT_H */
