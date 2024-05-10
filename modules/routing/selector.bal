// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Dynamic route selection engine evaluating cost, latency, and circuit breaker status.
#
# + intent - Transfer intent to route
# + railRegistry - Map of currently tracked payment rails and their health metrics
# + return - RoutingDecision or RailUnavailableError if no healthy route exists
public isolated function selectOptimalRail(
    types:TransferIntent intent,
    map<types:RailHealth> railRegistry
) returns types:RoutingDecision|types:RailUnavailableError {
    boolean isIntraInstitution = (intent.debtor.institution.bic == intent.creditor.institution.bic &&
       intent.debtor.institution.routingNumber == intent.creditor.institution.routingNumber);

    // Check if debtor and creditor belong to same institution for immediate INTERNAL routing
    if isIntraInstitution {
        return {
            chosenRail: types:INTERNAL,
            estimatedLatencyMs: 5,
            estimatedFeeCents: 0,
            routingRationale: "Intra-institution book transfer selected: zero clearing fee and instant execution",
            fallbackOrder: []
        };
    }

    // If client specified a preferred rail, evaluate its health and eligibility first
    types:PaymentRail? pref = intent.preferredRail;
    if pref is types:PaymentRail && pref != types:INTERNAL {
        string prefKey = pref.toString();
        if railRegistry.hasKey(prefKey) {
            types:RailHealth h = railRegistry.get(prefKey);
            if h.isAvailable && !h.circuitOpen && isCurrencySupported(h.rail, intent.currency) {
                int fee = calculateEstimatedFee(intent.amount, h);
                if fee <= intent.maxFeeCents {
                    types:PaymentRail[] fallbacks = determineFallbacks(h.rail, intent.currency, railRegistry, isIntraInstitution);
                    return {
                        chosenRail: h.rail,
                        estimatedLatencyMs: h.latencyP99Ms,
                        estimatedFeeCents: fee,
                        routingRationale: "Client preferred rail healthy and satisfied SLA limits",
                        fallbackOrder: fallbacks
                    };
                }
            }
        }
    }

    // Dynamic search across all healthy rails supporting this currency
    // Note: INTERNAL is strictly excluded for interbank transfers between distinct institutions
    types:PaymentRail[] candidates = [];
    foreach types:RailHealth h in railRegistry {
        if h.rail != types:INTERNAL && h.isAvailable && !h.circuitOpen && isCurrencySupported(h.rail, intent.currency) {
            candidates.push(h.rail);
        }
    }

    if candidates.length() == 0 {
        return error types:RailUnavailableError(
            "No active payment rail available for currency " + intent.currency.toString() + " meeting circuit safety"
        );
    }

    // Rank candidate rails: prefer lowest latency instant rails if within fee ceiling
    types:PaymentRail bestRail = candidates[0];
    int bestScore = 999999999;
    int bestFee = 0;
    int bestLatency = 0;

    foreach types:PaymentRail r in candidates {
        types:RailHealth h = railRegistry.get(r.toString());
        int fee = calculateEstimatedFee(intent.amount, h);
        if fee > intent.maxFeeCents && intent.preferredRail is () {
            continue;
        }

        // Composite scoring metric: latency weight + fee weight
        int score = h.latencyP99Ms + (fee * 10);
        if score < bestScore {
            bestScore = score;
            bestRail = r;
            bestFee = fee;
            bestLatency = h.latencyP99Ms;
        }
    }

    types:PaymentRail[] fallbacks = determineFallbacks(bestRail, intent.currency, railRegistry, isIntraInstitution);

    return {
        chosenRail: bestRail,
        estimatedLatencyMs: bestLatency,
        estimatedFeeCents: bestFee,
        routingRationale: "Optimized route selected via composite latency-fee multi-rail ranking",
        fallbackOrder: fallbacks
    };
}

# Estimates total clearing fee in minor currency cents based on volume and fixed rates.
#
# + amountStr - Decimal transfer amount
# + health - Target rail health and tariff configuration
# + return - Estimated total fee in cents
public isolated function calculateEstimatedFee(string amountStr, types:RailHealth health) returns int {
    fixedpoint:ScaledDecimal|types:FixedPointArithmeticError amt = fixedpoint:fromString(amountStr);
    if amt is types:FixedPointArithmeticError {
        return health.fixedFeeCents;
    }
    decimal volumeFee = amt.value * health.feePercentage * 100.0d;
    return health.fixedFeeCents + <int>volumeFee.round();
}

# Determines fallback failover order if chosen rail fails during dispatch.
#
# + chosen - Primary chosen rail
# + currency - Transfer currency
# + registry - Active rail health map
# + isIntra - True if intra-institution transfer
# + return - Array of eligible secondary rails
isolated function determineFallbacks(
    types:PaymentRail chosen,
    types:Currency currency,
    map<types:RailHealth> registry,
    boolean isIntra
) returns types:PaymentRail[] {
    types:PaymentRail[] fallbacks = [];
    foreach types:RailHealth h in registry {
        if !isIntra && h.rail == types:INTERNAL {
            continue;
        }
        if h.rail != chosen && h.isAvailable && !h.circuitOpen && isCurrencySupported(h.rail, currency) {
            fallbacks.push(h.rail);
        }
    }
    return fallbacks;
}
