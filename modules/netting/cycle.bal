// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Result of a multilateral netting optimization cycle.
#
# + cycleId - Unique clearing cycle UUID
# + status - Final cycle status (OPTIMIZED, COLLATERAL_DEFICIT, SETTLED)
# + currency - Clearing currency
# + totalGrossVolume - Aggregate volume before netting
# + totalNetVolume - Final settlement volume after netting
# + liquidityEfficiencyRatio - Percentage reduction in required clearing liquidity
# + participantObligations - Final net debit or credit position per participant
# + balanced - Invariant proof confirming sum of net debits equals sum of net credits
public type NettingCycleResult record {|
    string cycleId;
    types:NettingStatus status;
    types:Currency currency;
    string totalGrossVolume;
    string totalNetVolume;
    decimal liquidityEfficiencyRatio;
    types:NetObligation[] participantObligations;
    boolean balanced;
|};

# Executes multilateral netting algorithm across an array of bilateral payment obligations.
#
# + cycleId - Unique cycle identifier
# + debts - List of bilateral payment obligations to clear
# + currency - Denomination
# + collateralMgr - Collateral manager to verify debit capacity
# + return - NettingCycleResult or NettingDeficitError on collateral shortfall
public isolated function optimizeMultilateralCycle(
    string cycleId,
    types:BilateralDebt[] debts,
    types:Currency currency,
    CollateralManager collateralMgr
) returns NettingCycleResult|types:NettingDeficitError|types:FixedPointArithmeticError {
    map<fixedpoint:ScaledDecimal> grossDebits = {};
    map<fixedpoint:ScaledDecimal> grossCredits = {};
    fixedpoint:ScaledDecimal totalGross = check fixedpoint:fromString("0.00");

    // 1. Aggregate gross inflows and outflows per participant
    foreach types:BilateralDebt debt in debts {
        if debt.currency != currency {
            continue;
        }
        fixedpoint:ScaledDecimal amt = check fixedpoint:fromString(debt.amount);
        totalGross = fixedpoint:add(totalGross, amt);

        // Debtor leg
        if !grossDebits.hasKey(debt.debtorBic) {
            grossDebits[debt.debtorBic] = amt;
        } else {
            grossDebits[debt.debtorBic] = fixedpoint:add(grossDebits.get(debt.debtorBic), amt);
        }

        // Creditor leg
        if !grossCredits.hasKey(debt.creditorBic) {
            grossCredits[debt.creditorBic] = amt;
        } else {
            grossCredits[debt.creditorBic] = fixedpoint:add(grossCredits.get(debt.creditorBic), amt);
        }
    }

    // Identify union of all participant BICs
    map<boolean> participantMap = {};
    foreach string bic in grossDebits.keys() {
        participantMap[bic] = true;
    }
    foreach string bic in grossCredits.keys() {
        participantMap[bic] = true;
    }

    types:NetObligation[] obligations = [];
    fixedpoint:ScaledDecimal totalNetDebits = check fixedpoint:fromString("0.00");
    fixedpoint:ScaledDecimal totalNetCredits = check fixedpoint:fromString("0.00");

    fixedpoint:ScaledDecimal zeroDec = check fixedpoint:fromString("0.00");

    // 2. Compute net positions and verify collateral
    foreach string bic in participantMap.keys() {
        fixedpoint:ScaledDecimal dr = grossDebits.hasKey(bic) ? grossDebits.get(bic) : zeroDec;
        fixedpoint:ScaledDecimal cr = grossCredits.hasKey(bic) ? grossCredits.get(bic) : zeroDec;

        fixedpoint:ScaledDecimal net = fixedpoint:sub(cr, dr);
        boolean isCreditor = fixedpoint:isPositive(net);
        string posStr = fixedpoint:formatFinancial(net, 2);

        if !isCreditor && !fixedpoint:isZero(net) {
            fixedpoint:ScaledDecimal netDebitAmt = fixedpoint:abs(net);
            string netDebitStr = fixedpoint:formatFinancial(netDebitAmt, 2);
            totalNetDebits = fixedpoint:add(totalNetDebits, netDebitAmt);

            // Verify collateral capacity
            boolean hasCollateral = collateralMgr.hasSufficientCollateral(bic, netDebitStr);
            if !hasCollateral {
                return error types:NettingDeficitError(
                    "Collateral deficit for clearing participant " + bic + ": net debit " + netDebitStr + " exceeds posted margin"
                );
            }

            obligations.push({
                participantBic: bic,
                netDebitAmount: netDebitStr,
                netCreditAmount: "0.00",
                netPosition: posStr,
                isCreditor: false
            });
        } else if (isCreditor) {
            totalNetCredits = fixedpoint:add(totalNetCredits, net);
            obligations.push({
                participantBic: bic,
                netDebitAmount: "0.00",
                netCreditAmount: posStr,
                netPosition: posStr,
                isCreditor: true
            });
        } else {
            // Net zero
            obligations.push({
                participantBic: bic,
                netDebitAmount: "0.00",
                netCreditAmount: "0.00",
                netPosition: "0.00",
                isCreditor: false
            });
        }
    }

    // 3. Multilateral Invariant Verification: sum of net debits must equal sum of net credits
    boolean isBalanced = fixedpoint:compare(totalNetDebits, totalNetCredits) == 0;

    // Liquidity efficiency ratio: 1.0 - (totalNet / totalGross)
    decimal grossVal = totalGross.value;
    decimal netVal = totalNetDebits.value;
    decimal efficiency = grossVal > 0.0d ? (1.0d - (netVal / grossVal)) * 100.0d : 0.0d;

    return {
        cycleId: cycleId,
        status: types:NETTING_OPTIMIZED,
        currency: currency,
        totalGrossVolume: fixedpoint:formatFinancial(totalGross, 2),
        totalNetVolume: fixedpoint:formatFinancial(totalNetDebits, 2),
        liquidityEfficiencyRatio: efficiency,
        participantObligations: obligations,
        balanced: isBalanced
    };
}
