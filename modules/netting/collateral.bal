// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Collateral reserve snapshot for a clearing participant institution.
#
# + participantBic - Unique BIC of clearing participant
# + postedCollateral - Total pledged collateral
# + creditLimit - Maximum intraday net debit ceiling
# + currency - Collateral denomination
# + updatedAtEpochNs - Last collateral mutation timestamp
public type CollateralAccount record {|
    string participantBic;
    string postedCollateral;
    string creditLimit;
    types:Currency currency;
    int updatedAtEpochNs;
|};

# Manages participant collateral pools and verifies intraday debit capacity.
public class CollateralManager {
    private final map<CollateralAccount> accounts = {};

    # Initializes empty collateral manager.
    public isolated function init() {
    }

    # Registers or updates collateral for a clearing bank.
    #
    # + bic - Participant BIC
    # + collateralAmount - Posted collateral amount
    # + creditLimitAmount - Intraday credit line
    # + currency - Collateral currency
    # + nowEpochNs - Epoch timestamp
    public isolated function setCollateral(
        string bic,
        string collateralAmount,
        string creditLimitAmount,
        types:Currency currency,
        int nowEpochNs
    ) {
        lock {
            self.accounts[bic] = {
                participantBic: bic,
                postedCollateral: collateralAmount,
                creditLimit: creditLimitAmount,
                currency: currency,
                updatedAtEpochNs: nowEpochNs
            };
        }
    }

    # Verifies whether a participant has sufficient collateral to back a projected net debit position.
    #
    # + bic - Participant BIC
    # + netDebitAmountStr - Projected net obligation
    # + return - True if net debit is within collateral + credit limit
    public isolated function hasSufficientCollateral(string bic, string netDebitAmountStr) returns boolean {
        lock {
            if !self.accounts.hasKey(bic) {
                return false;
            }
            CollateralAccount acc = self.accounts.get(bic);

            fixedpoint:ScaledDecimal|error netDebit = fixedpoint:fromString(netDebitAmountStr);
            if netDebit is error {
                return false;
            }

            fixedpoint:ScaledDecimal|error posted = fixedpoint:fromString(acc.postedCollateral);
            fixedpoint:ScaledDecimal|error credit = fixedpoint:fromString(acc.creditLimit);
            if posted is error || credit is error {
                return false;
            }

            fixedpoint:ScaledDecimal maxCapacity = fixedpoint:add(posted, credit);
            return fixedpoint:compare(maxCapacity, netDebit) >= 0;
        }
    }
}
