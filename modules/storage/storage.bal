// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Storage engine combining WAL durability, snapshot compaction, and Merkle audit trails.
public class StorageEngine {
    private final WalManager wal = new ();
    private final SnapshotManager snapshots = new ();

    # Initializes storage engine.
    public isolated function init() {
    }

    # Retrieves Write-Ahead Log manager.
    #
    # + return - WalManager reference
    public isolated function getWalManager() returns WalManager {
        return self.wal;
    }

    # Retrieves snapshot manager.
    #
    # + return - SnapshotManager reference
    public isolated function getSnapshotManager() returns SnapshotManager {
        return self.snapshots;
    }
}
