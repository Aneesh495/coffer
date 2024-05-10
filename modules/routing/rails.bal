// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Default health and fee characteristics for supported payment rails.
#
# + rail - Payment rail
# + return - Initialized RailHealth configuration
public isolated function createDefaultRailHealth(types:PaymentRail rail) returns types:RailHealth {
    match rail {
        types:FEDNOW => {
            return {
                rail: types:FEDNOW,
                isAvailable: true,
                latencyP99Ms: 450,
                feePercentage: 0.0001d,
                fixedFeeCents: 5,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 5,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
        types:SEPA_INSTANT => {
            return {
                rail: types:SEPA_INSTANT,
                isAvailable: true,
                latencyP99Ms: 1200,
                feePercentage: 0.0002d,
                fixedFeeCents: 20,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 5,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
        types:RTP => {
            return {
                rail: types:RTP,
                isAvailable: true,
                latencyP99Ms: 650,
                feePercentage: 0.00015d,
                fixedFeeCents: 10,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 5,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
        types:ACH => {
            return {
                rail: types:ACH,
                isAvailable: true,
                latencyP99Ms: 14400000, // Batch overnight
                feePercentage: 0.00005d,
                fixedFeeCents: 1,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 10,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
        types:SWIFT => {
            return {
                rail: types:SWIFT,
                isAvailable: true,
                latencyP99Ms: 7200000,
                feePercentage: 0.001d,
                fixedFeeCents: 1500,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 8,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
        _ => {
            // INTERNAL
            return {
                rail: types:INTERNAL,
                isAvailable: true,
                latencyP99Ms: 5,
                feePercentage: 0.0d,
                fixedFeeCents: 0,
                failureCount: 0,
                consecutiveErrors: 0,
                circuitTripThreshold: 100,
                circuitOpen: false,
                circuitHalfOpenEpochMs: 0
            };
        }
    }
}

# Verifies whether a given payment rail supports the transaction currency.
#
# + rail - Payment rail
# + currency - ISO 4217 currency
# + return - True if supported
public isolated function isCurrencySupported(types:PaymentRail rail, types:Currency currency) returns boolean {
    match rail {
        types:FEDNOW => {
            return currency == types:USD;
        }
        types:SEPA_INSTANT => {
            return currency == types:EUR;
        }
        types:RTP => {
            return currency == types:USD;
        }
        types:ACH => {
            return currency == types:USD;
        }
        types:SWIFT => {
            return true;
        }
        types:INTERNAL => {
            return true;
        }
        _ => {
            return false;
        }
    }
}
