// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/crypto;
import aneeshkrishna/coffer.types;

# Discrete types of events recorded into the durable Write-Ahead Log.
public enum WalRecordType {
    WAL_TX_INIT = "TX_INIT",
    WAL_TX_SETTLED = "TX_SETTLED",
    WAL_LEDGER_POSTING = "LEDGER_POSTING",
    WAL_NETTING_CYCLE = "NETTING_CYCLE",
    WAL_SNAPSHOT = "SNAPSHOT"
}

# In-memory structured representation of a Write-Ahead Log frame.
#
# + lsn - Monotonic 64-bit Log Sequence Number
# + recordType - Classification of logged event
# + payload - Raw event payload string
# + checksum - SHA-256 prefix or CRC checksum string for integrity verification
# + timestampEpochNs - Logging timestamp
public type WalRecord record {|
    int lsn;
    WalRecordType recordType;
    string payload;
    string checksum;
    int timestampEpochNs;
|};

# Append-only Write-Ahead Log engine with crash recovery and checksum integrity checks.
public class WalManager {
    private int currentLsn = 0;
    private final WalRecord[] logRecords = [];

    # Initializes empty WAL manager.
    public isolated function init() {
    }

    # Appends a new event record into the durable log.
    #
    # + rType - WalRecordType
    # + payload - Serialized event string
    # + nowEpochNs - Epoch timestamp
    # + return - Created WalRecord with assigned monotonic LSN
    public isolated function append(WalRecordType rType, string payload, int nowEpochNs) returns WalRecord {
        lock {
            self.currentLsn = self.currentLsn + 1;
            int lsn = self.currentLsn;

            // Compute checksum over LSN + recordType + payload
            string rawContent = lsn.toString() + ":" + rType.toString() + ":" + payload;
            byte[] hashBytes = crypto:hashSha256(rawContent.toBytes());
            string checksum = hashBytes.toBase16();

            WalRecord recordItem = {
                lsn: lsn,
                recordType: rType,
                payload: payload,
                checksum: checksum,
                timestampEpochNs: nowEpochNs
            };

            self.logRecords.push(recordItem);
            return recordItem;
        }
    }

    # Replays log records from the beginning, validating cryptographic checksums for every entry.
    #
    # + return - Array of verified WalRecords or StorageCorruptionError if tampering or torn-write detected
    public isolated function replayAndVerify() returns WalRecord[]|types:StorageCorruptionError {
        lock {
            WalRecord[] verified = [];
            int expectedLsn = 1;

            foreach WalRecord rec in self.logRecords {
                if rec.lsn != expectedLsn {
                    return error types:StorageCorruptionError(
                        "WAL sequence disruption: expected LSN " + expectedLsn.toString() + " but found " + rec.lsn.toString()
                    );
                }

                string rawContent = rec.lsn.toString() + ":" + rec.recordType.toString() + ":" + rec.payload;
                byte[] expectedHashBytes = crypto:hashSha256(rawContent.toBytes());
                string expectedChecksum = expectedHashBytes.toBase16();

                if rec.checksum != expectedChecksum {
                    return error types:StorageCorruptionError(
                        "WAL checksum corruption at LSN " + rec.lsn.toString() + ": checksum mismatch"
                    );
                }

                verified.push(rec);
                expectedLsn = expectedLsn + 1;
            }

            return verified;
        }
    }

    # Returns the total number of records committed to the log.
    #
    # + return - Record count
    public isolated function getRecordCount() returns int {
        lock {
            return self.logRecords.length();
        }
    }

    # Retrieves highest committed Log Sequence Number.
    #
    # + return - Current LSN
    public isolated function getCurrentLsn() returns int {
        lock {
            return self.currentLsn;
        }
    }
}
