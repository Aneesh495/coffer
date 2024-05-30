// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Point-in-time serialized snapshot of ledger and transaction state.
#
# + snapshotId - Unique snapshot UUID
# + lastCommittedLsn - Monotonic LSN boundary included in snapshot
# + timestampEpochNs - Snapshot creation timestamp
# + accountCount - Total number of accounts captured
# + transactionCount - Total number of settled transactions captured
# + stateDigest - Cryptographic SHA-256 fingerprint of captured state
public type StateSnapshot record {|
    string snapshotId;
    int lastCommittedLsn;
    int timestampEpochNs;
    int accountCount;
    int transactionCount;
    string stateDigest;
|};

# Manages point-in-time snapshots for log compaction.
public class SnapshotManager {
    private StateSnapshot? latestSnapshot = ();

    # Initializes snapshot manager.
    public isolated function init() {
    }

    # Saves a new state snapshot.
    #
    # + snap - StateSnapshot record
    public isolated function saveSnapshot(StateSnapshot snap) {
        lock {
            self.latestSnapshot = snap;
        }
    }

    # Retrieves latest saved snapshot.
    #
    # + return - StateSnapshot or nil if none taken yet
    public isolated function getLatestSnapshot() returns StateSnapshot? {
        lock {
            return self.latestSnapshot;
        }
    }
}
