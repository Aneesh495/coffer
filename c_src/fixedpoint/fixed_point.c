/*
 * Copyright (c) 2026 Aneesh Krishna
 * Licensed under the MIT License. See LICENSE for details.
 *
 * Coffer Native C Acceleration Engine: 128-Bit Fixed-Point Arithmetic Implementation
 */

#include "fixed_point.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

coffer_fp_t coffer_fp_from_int(int64_t integer_val) {
    coffer_fp_t res;
    res.raw = ((__int128_t)integer_val) * COFFER_FP_SCALE_FACTOR;
    return res;
}

coffer_fp_t coffer_fp_from_minor(int64_t minor_units, int minor_scale) {
    coffer_fp_t res;
    __int128_t factor = 1;
    for (int i = 0; i < (COFFER_FP_SCALE - minor_scale); i++) {
        factor *= 10;
    }
    res.raw = ((__int128_t)minor_units) * factor;
    return res;
}

bool coffer_fp_from_string(const char *str, coffer_fp_t *out) {
    if (!str || !out) return false;
    while (isspace((unsigned char)*str)) str++;
    if (*str == '\0') return false;

    bool negative = false;
    if (*str == '-') {
        negative = true;
        str++;
    } else if (*str == '+') {
        str++;
    }

    __int128_t whole = 0;
    while (*str >= '0' && *str <= '9') {
        whole = whole * 10 + (*str - '0');
        str++;
    }

    __int128_t frac = 0;
    int frac_digits = 0;
    if (*str == '.') {
        str++;
        while (*str >= '0' && *str <= '9') {
            if (frac_digits < COFFER_FP_SCALE) {
                frac = frac * 10 + (*str - '0');
                frac_digits++;
            }
            str++;
        }
    }

    while (frac_digits < COFFER_FP_SCALE) {
        frac *= 10;
        frac_digits++;
    }

    __int128_t total = whole * COFFER_FP_SCALE_FACTOR + frac;
    if (negative) total = -total;

    out->raw = total;
    return true;
}

void coffer_fp_to_string(coffer_fp_t val, char *buffer, size_t buffer_size, int decimals) {
    if (!buffer || buffer_size == 0) return;

    __int128_t v = val.raw;
    bool negative = false;
    if (v < 0) {
        negative = true;
        v = -v;
    }

    if (decimals < 0) decimals = 2;
    if (decimals > COFFER_FP_SCALE) decimals = COFFER_FP_SCALE;

    __int128_t whole = v / COFFER_FP_SCALE_FACTOR;
    __int128_t remainder = v % COFFER_FP_SCALE_FACTOR;

    /* Rounding remainder to requested decimals */
    __int128_t divisor = 1;
    for (int i = 0; i < (COFFER_FP_SCALE - decimals); i++) {
        divisor *= 10;
    }

    __int128_t frac = remainder / divisor;
    __int128_t next_digit = (remainder / (divisor / 10)) % 10;
    if (divisor > 1 && next_digit >= 5) {
        frac++;
        __int128_t max_frac = 1;
        for (int i = 0; i < decimals; i++) max_frac *= 10;
        if (frac >= max_frac) {
            whole++;
            frac = 0;
        }
    }

    char whole_str[64];
    int w_idx = 0;
    if (whole == 0) {
        whole_str[w_idx++] = '0';
    } else {
        __int128_t temp = whole;
        char rev[64];
        int r_idx = 0;
        while (temp > 0) {
            rev[r_idx++] = (char)('0' + (temp % 10));
            temp /= 10;
        }
        while (r_idx > 0) {
            whole_str[w_idx++] = rev[--r_idx];
        }
    }
    whole_str[w_idx] = '\0';

    if (decimals == 0) {
        snprintf(buffer, buffer_size, "%s%s", negative ? "-" : "", whole_str);
    } else {
        char frac_str[32];
        snprintf(frac_str, sizeof(frac_str), "%0*lld", decimals, (long long)frac);
        snprintf(buffer, buffer_size, "%s%s.%s", negative ? "-" : "", whole_str, frac_str);
    }
}

int64_t coffer_fp_to_minor(coffer_fp_t val, int minor_scale) {
    __int128_t factor = 1;
    for (int i = 0; i < (COFFER_FP_SCALE - minor_scale); i++) {
        factor *= 10;
    }
    __int128_t rounded = val.raw + (factor / 2);
    return (int64_t)(rounded / factor);
}

coffer_fp_t coffer_fp_add(coffer_fp_t a, coffer_fp_t b) {
    coffer_fp_t res;
    res.raw = a.raw + b.raw;
    return res;
}

coffer_fp_t coffer_fp_sub(coffer_fp_t a, coffer_fp_t b) {
    coffer_fp_t res;
    res.raw = a.raw - b.raw;
    return res;
}

coffer_fp_t coffer_fp_mul(coffer_fp_t a, coffer_fp_t b) {
    coffer_fp_t res;
    res.raw = (a.raw * b.raw) / COFFER_FP_SCALE_FACTOR;
    return res;
}

bool coffer_fp_div(coffer_fp_t a, coffer_fp_t b, coffer_fp_t *out) {
    if (!out || b.raw == 0) return false;
    out->raw = (a.raw * COFFER_FP_SCALE_FACTOR) / b.raw;
    return true;
}

coffer_fp_t coffer_fp_abs(coffer_fp_t a) {
    coffer_fp_t res;
    res.raw = a.raw < 0 ? -a.raw : a.raw;
    return res;
}

coffer_fp_t coffer_fp_sat_sub(coffer_fp_t a, coffer_fp_t b) {
    coffer_fp_t res;
    if (b.raw >= a.raw) {
        res.raw = 0;
    } else {
        res.raw = a.raw - b.raw;
    }
    return res;
}

int coffer_fp_cmp(coffer_fp_t a, coffer_fp_t b) {
    if (a.raw < b.raw) return -1;
    if (a.raw > b.raw) return 1;
    return 0;
}

bool coffer_fp_is_zero(coffer_fp_t a) {
    return a.raw == 0;
}

bool coffer_fp_is_positive(coffer_fp_t a) {
    return a.raw > 0;
}

bool coffer_fp_is_negative(coffer_fp_t a) {
    return a.raw < 0;
}

bool coffer_fp_verify_balance(const coffer_fp_t *debits, size_t debit_count,
                              const coffer_fp_t *credits, size_t credit_count) {
    __int128_t sum_debits = 0;
    for (size_t i = 0; i < debit_count; i++) {
        sum_debits += debits[i].raw;
    }

    __int128_t sum_credits = 0;
    for (size_t i = 0; i < credit_count; i++) {
        sum_credits += credits[i].raw;
    }

    return sum_debits == sum_credits;
}
