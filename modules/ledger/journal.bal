// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/crypto;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Validates and builds a balanced JournalBatch from an array of debit and credit entries.
#
# + batchId - Unique journal batch identifier
# + txId - Associated transaction UUID
# + entries - List of ledger postings
# + nowEpochNs - Commit timestamp in nanoseconds
# + return - Balanced JournalBatch or LedgerInvariantError if debits do not equal credits
public isolated function buildJournalBatch(
    string batchId,
    string txId,
    types:LedgerEntry[] entries,
    int nowEpochNs
) returns types:JournalBatch|types:LedgerInvariantError|types:FixedPointArithmeticError {
    if entries.length() < 2 {
        return error types:LedgerInvariantError("A double-entry journal batch must contain at least two postings");
    }

    fixedpoint:ScaledDecimal[] debits = [];
    fixedpoint:ScaledDecimal[] credits = [];

    string concatenatedEntries = batchId + ":" + txId;

    foreach types:LedgerEntry entry in entries {
        fixedpoint:ScaledDecimal amt = check fixedpoint:fromString(entry.amount);
        if entry.direction == types:DEBIT {
            debits.push(amt);
        } else {
            credits.push(amt);
        }
        concatenatedEntries = concatenatedEntries + "|" + entry.entryId + ":" + entry.accountId + ":" + entry.amount;
    }

    boolean isBalanced = fixedpoint:verifyBalance(debits, credits);
    if !isBalanced {
        return error types:LedgerInvariantError(
            "Double-entry invariant violation: total debits do not match total credits in batch " + batchId
        );
    }

    // Compute SHA-256 Merkle root / digest of the batch
    byte[] hashBytes = crypto:hashSha256(concatenatedEntries.toBytes());
    string merkleRoot = hashBytes.toBase16();

    return {
        batchId: batchId,
        transactionId: txId,
        entries: entries,
        createdAtEpochNs: nowEpochNs,
        merkleRoot: merkleRoot,
        balanced: true
    };
}
