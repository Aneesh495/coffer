// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Record holding a quarantined transaction awaiting compliance review.
#
# + transactionId - Target transaction UUID
# + intent - Original transfer intent
# + riskScore - Assessed risk score
# + triggers - Triggered risk reasons
# + quarantinedAtEpochNs - Timestamp placed into quarantine
# + status - PENDING_REVIEW, RELEASED, or REJECTED
public type QuarantinedItem record {|
    string transactionId;
    types:TransferIntent intent;
    int riskScore;
    string[] triggers;
    int quarantinedAtEpochNs;
    string status;
|};

# Thread-safe quarantine store for flagged payments.
public class QuarantineStore {
    private final map<QuarantinedItem> items = {};

    # Initializes empty quarantine store.
    public isolated function init() {
    }

    # Places a transaction into quarantine.
    #
    # + item - QuarantinedItem record
    public isolated function add(QuarantinedItem item) {
        lock {
            self.items[item.transactionId] = item;
        }
    }

    # Releases a transaction from quarantine following compliance approval.
    #
    # + transactionId - Transaction UUID
    # + return - QuarantinedItem snapshot or error if not found
    public isolated function release(string transactionId) returns QuarantinedItem|error {
        lock {
            if !self.items.hasKey(transactionId) {
                return error("Quarantined transaction not found: " + transactionId);
            }
            QuarantinedItem item = self.items.get(transactionId);
            item.status = "RELEASED";
            self.items[transactionId] = item;
            return item;
        }
    }

    # Rejects a quarantined transaction permanently.
    #
    # + transactionId - Transaction UUID
    # + return - QuarantinedItem snapshot or error if not found
    public isolated function reject(string transactionId) returns QuarantinedItem|error {
        lock {
            if !self.items.hasKey(transactionId) {
                return error("Quarantined transaction not found: " + transactionId);
            }
            QuarantinedItem item = self.items.get(transactionId);
            item.status = "REJECTED";
            self.items[transactionId] = item;
            return item;
        }
    }

    # Retrieves all items currently in quarantine.
    #
    # + return - Array of QuarantinedItem records
    public isolated function getAll() returns QuarantinedItem[] {
        lock {
            QuarantinedItem[] res = [];
            foreach QuarantinedItem it in self.items {
                res.push(it);
            }
            return res;
        }
    }
}
