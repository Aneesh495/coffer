// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Creates a new ledger account adhering to financial accounting classification.
#
# + id - Unique account UUID
# + identifier - External account or IBAN identifier
# + name - Account title or holder moniker
# + accountType - Fundamental class: ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
# + category - Granular operational category (CUSTOMER_CHECKING, NOSTRO, etc.)
# + currency - ISO 4217 denomination
# + initialBalance - Initial settled balance as string
# + nowEpochNs - Creation timestamp in nanoseconds
# + return - Initialized Account record or FixedPointArithmeticError on invalid balance string
public isolated function createAccount(
    string id,
    string identifier,
    string name,
    types:AccountType accountType,
    types:AccountCategory category,
    types:Currency currency,
    string initialBalance,
    int nowEpochNs
) returns types:Account|types:FixedPointArithmeticError {
    fixedpoint:ScaledDecimal initDec = check fixedpoint:fromString(initialBalance);
    string balStr = fixedpoint:formatFinancial(initDec, 2);

    return {
        id: id,
        accountIdentifier: identifier,
        name: name,
        accountType: accountType,
        category: category,
        currency: currency,
        status: types:ACTIVE,
        settledBalance: balStr,
        pendingHoldsBalance: "0.00",
        availableBalance: balStr,
        version: 1,
        createdAtEpochNs: nowEpochNs,
        updatedAtEpochNs: nowEpochNs
    };
}

# Calculates whether an account has sufficient spendable funds for an operation.
#
# + account - Target account to inspect
# + amount - Requested amount as string
# + return - True if available balance covers requested amount
public isolated function hasSufficientFunds(types:Account account, string amount) returns boolean {
    fixedpoint:ScaledDecimal|types:FixedPointArithmeticError reqDec = fixedpoint:fromString(amount);
    if reqDec is types:FixedPointArithmeticError {
        return false;
    }
    fixedpoint:ScaledDecimal|types:FixedPointArithmeticError availDec = fixedpoint:fromString(account.availableBalance);
    if availDec is types:FixedPointArithmeticError {
        return false;
    }
    return fixedpoint:compare(availDec, reqDec) >= 0;
}
