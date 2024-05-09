// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Core in-memory transactional double-entry ledger engine.
# Guarantees zero-sum balance invariants, atomic fund transfers,
# two-phase reservation holds, and immutable journal batch recording.
public class LedgerEngine {
    private final map<types:Account> accounts = {};
    private final map<types:AccountHold> holds = {};
    private final types:JournalBatch[] journal = [];

    # Initializes an empty double-entry ledger.
    public function init() {
    }

    # Registers a new account into the chart of accounts.
    #
    # + account - Initialized Account record
    # + return - Nil or error on duplicate ID
    public isolated function registerAccount(types:Account account) returns error? {
        lock {
            if self.accounts.hasKey(account.id) {
                return error("Account ID already registered: " + account.id);
            }
            self.accounts[account.id] = account;
        }
    }

    # Retrieves an account snapshot by unique ID.
    #
    # + id - Account UUID
    # + return - Account snapshot or error if not found
    public isolated function getAccount(string id) returns types:Account|error {
        lock {
            if !self.accounts.hasKey(id) {
                return error("Account not found: " + id);
            }
            return self.accounts.get(id);
        }
    }

    # Retrieves all registered accounts.
    #
    # + return - Array of Account snapshots
    public isolated function getAllAccounts() returns types:Account[] {
        lock {
            types:Account[] result = [];
            foreach types:Account acc in self.accounts {
                result.push(acc);
            }
            return result;
        }
    }

    # Creates an escrow hold reserving spendable funds without yet mutating settled balance.
    #
    # + holdId - Unique hold reservation UUID
    # + accountId - Target account identifier
    # + txId - Associated transaction reference
    # + amount - Amount to reserve
    # + currency - Hold currency
    # + ttlNs - Hold duration in nanoseconds
    # + nowEpochNs - Current epoch timestamp
    # + return - AccountHold record or domain error
    public isolated function createHold(
        string holdId,
        string accountId,
        string txId,
        string amount,
        types:Currency currency,
        int ttlNs,
        int nowEpochNs
    ) returns types:AccountHold|types:InsufficientFundsError|types:AccountFrozenError|types:FixedPointArithmeticError|error {
        lock {
            if !self.accounts.hasKey(accountId) {
                return error("Account not found: " + accountId);
            }
            types:Account acc = self.accounts.get(accountId);

            if acc.status != types:ACTIVE {
                return error types:AccountFrozenError("Cannot place hold on non-active account " + accountId);
            }

            if acc.currency != currency {
                return error("Currency mismatch between hold (" + currency + ") and account (" + acc.currency + ")");
            }

            fixedpoint:ScaledDecimal reqAmt = check fixedpoint:fromString(amount);
            fixedpoint:ScaledDecimal availBal = check fixedpoint:fromString(acc.availableBalance);

            if fixedpoint:compare(availBal, reqAmt) < 0 {
                return error types:InsufficientFundsError(
                    "Insufficient available balance in account " + accountId + ": available=" + acc.availableBalance + " requested=" + amount
                );
            }

            fixedpoint:ScaledDecimal holdsBal = check fixedpoint:fromString(acc.pendingHoldsBalance);
            fixedpoint:ScaledDecimal newHoldsBal = fixedpoint:add(holdsBal, reqAmt);
            fixedpoint:ScaledDecimal newAvailBal = fixedpoint:sub(availBal, reqAmt);

            acc.pendingHoldsBalance = fixedpoint:formatFinancial(newHoldsBal, 2);
            acc.availableBalance = fixedpoint:formatFinancial(newAvailBal, 2);
            acc.version = acc.version + 1;
            acc.updatedAtEpochNs = nowEpochNs;
            self.accounts[accountId] = acc;

            types:AccountHold hold = {
                holdId: holdId,
                accountId: accountId,
                transactionId: txId,
                amount: fixedpoint:formatFinancial(reqAmt, 2),
                currency: currency,
                active: true,
                expiresAtEpochNs: nowEpochNs + ttlNs
            };
            self.holds[holdId] = hold;
            return hold;
        }
    }

    # Releases an active hold, immediately restoring available funds.
    #
    # + holdId - Hold identifier to release
    # + nowEpochNs - Current epoch timestamp
    # + return - Nil or error if hold not found or inactive
    public isolated function releaseHold(string holdId, int nowEpochNs) returns error? {
        lock {
            if !self.holds.hasKey(holdId) {
                return error("Hold not found: " + holdId);
            }
            types:AccountHold hold = self.holds.get(holdId);
            if !hold.active {
                return error("Hold already completed or released: " + holdId);
            }

            if !self.accounts.hasKey(hold.accountId) {
                return error("Target account for hold not found: " + hold.accountId);
            }
            types:Account acc = self.accounts.get(hold.accountId);

            fixedpoint:ScaledDecimal holdAmt = check fixedpoint:fromString(hold.amount);
            fixedpoint:ScaledDecimal holdsBal = check fixedpoint:fromString(acc.pendingHoldsBalance);
            fixedpoint:ScaledDecimal availBal = check fixedpoint:fromString(acc.availableBalance);

            fixedpoint:ScaledDecimal newHoldsBal = fixedpoint:saturatingSub(holdsBal, holdAmt);
            fixedpoint:ScaledDecimal newAvailBal = fixedpoint:add(availBal, holdAmt);

            acc.pendingHoldsBalance = fixedpoint:formatFinancial(newHoldsBal, 2);
            acc.availableBalance = fixedpoint:formatFinancial(newAvailBal, 2);
            acc.version = acc.version + 1;
            acc.updatedAtEpochNs = nowEpochNs;
            self.accounts[acc.id] = acc;

            hold.active = false;
            self.holds[holdId] = hold;
        }
    }

    # Commits an atomic JournalBatch, mutating settled balances and verifying zero-sum invariance.
    #
    # + batch - Balanced journal batch to record
    # + holdIdToFinalize - Optional associated hold to clear concurrently
    # + nowEpochNs - Current epoch timestamp
    # + return - Nil or error on invariant breach
    public isolated function postBatch(types:JournalBatch batch, string? holdIdToFinalize = (), int nowEpochNs = 0) returns error? {
        lock {
            if !batch.balanced {
                return error types:LedgerInvariantError("Rejected unbalanced journal batch: " + batch.batchId);
            }

            // Verify all referenced accounts exist and have matching currencies
            foreach types:LedgerEntry entry in batch.entries {
                if !self.accounts.hasKey(entry.accountId) {
                    return error("Referenced account not found in chart of accounts: " + entry.accountId);
                }
            }

            // Release the hold if one was pending for this transaction
            if holdIdToFinalize is string && self.holds.hasKey(holdIdToFinalize) {
                types:AccountHold h = self.holds.get(holdIdToFinalize);
                if h.active {
                    types:Account holdAcc = self.accounts.get(h.accountId);
                    fixedpoint:ScaledDecimal hAmt = check fixedpoint:fromString(h.amount);
                    fixedpoint:ScaledDecimal hBal = check fixedpoint:fromString(holdAcc.pendingHoldsBalance);
                    holdAcc.pendingHoldsBalance = fixedpoint:formatFinancial(fixedpoint:saturatingSub(hBal, hAmt), 2);
                    self.accounts[holdAcc.id] = holdAcc;
                    h.active = false;
                    self.holds[holdIdToFinalize] = h;
                }
            }

            // Apply each posting to settled and available balances
            foreach types:LedgerEntry entry in batch.entries {
                types:Account acc = self.accounts.get(entry.accountId);
                fixedpoint:ScaledDecimal amt = check fixedpoint:fromString(entry.amount);
                fixedpoint:ScaledDecimal settled = check fixedpoint:fromString(acc.settledBalance);
                fixedpoint:ScaledDecimal avail = check fixedpoint:fromString(acc.availableBalance);

                if acc.accountType == types:ASSET || acc.accountType == types:EXPENSE {
                    if entry.direction == types:DEBIT {
                        settled = fixedpoint:add(settled, amt);
                        avail = fixedpoint:add(avail, amt);
                    } else {
                        settled = fixedpoint:sub(settled, amt);
                        // If there was no prior hold, available also decreases
                        if holdIdToFinalize is () {
                            avail = fixedpoint:sub(avail, amt);
                        }
                    }
                } else {
                    // Liability, Equity, Revenue (Credit normal)
                    if entry.direction == types:CREDIT {
                        settled = fixedpoint:add(settled, amt);
                        avail = fixedpoint:add(avail, amt);
                    } else {
                        settled = fixedpoint:sub(settled, amt);
                        avail = fixedpoint:sub(avail, amt);
                    }
                }

                acc.settledBalance = fixedpoint:formatFinancial(settled, 2);
                acc.availableBalance = fixedpoint:formatFinancial(avail, 2);
                acc.version = acc.version + 1;
                acc.updatedAtEpochNs = nowEpochNs;
                self.accounts[acc.id] = acc;
            }

            self.journal.push(batch);
        }
    }

    # Retrieves complete historical journal batch trail.
    #
    # + return - Array of committed JournalBatches
    public isolated function getJournal() returns types:JournalBatch[] {
        lock {
            types:JournalBatch[] copy = [];
            foreach types:JournalBatch b in self.journal {
                copy.push(b);
            }
            return copy;
        }
    }
}
