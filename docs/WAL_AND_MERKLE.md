# Durability, Write-Ahead Logging, and Merkle Audit Trees

## 1. Storage Subsystem Overview

Coffer provides strict crash recovery and cryptographic auditability without relying on heavy external database engines. The storage architecture consists of three tightly coupled primitives:

1. **Append-Only Write-Ahead Log (WAL)**: Records every balance mutation and transaction state transition sequentially with 32-bit CRC checksum validation.
2. **Periodic State Snapshots**: Periodically serializes full in-memory account ledgers and pending holds, bounding crash-recovery replay time.
3. **Binary Merkle Audit Trees**: Computes RFC 6234 compliant SHA-256 binary hash trees over journal batches to guarantee tamper-evident audit trails.

```
       APPLICATION WRITE OPERATION
                   |
                   v
   +-------------------------------+
   | Compute Payload & CRC32 Hash  |
   +---------------+---------------+
                   |
                   v
   +-------------------------------+
   | Append Frame to coffer.wal    |
   +---------------+---------------+
                   |
                   v
   +-------------------------------+
   | Commit In-Memory State & Cache|
   +---------------+---------------+
                   |
                   +----(every 10k txs)----> [Write Snapshot to coffer.snap]
```

---

## 2. WAL Frame Binary Layout

WAL entries are written in discrete, length-prefixed binary frames:

```
+---------------+---------------+---------------+---------------+-------------------+
| Magic (4B)    | Length (4B)   | Sequence (8B) | CRC32 (4B)    | Payload (N Bytes) |
| 0x434F4646    | uint32_be     | uint64_be     | uint32_be     | UTF-8 JSON Frame  |
+---------------+---------------+---------------+---------------+-------------------+
```

- **Magic Prefix**: Four-byte constant `0x434F4646` (`"COFF"`) used to locate frame boundaries during corrupted log recovery.
- **Payload Length**: 32-bit big-endian integer specifying exact payload byte count.
- **Sequence Number**: Monotonically increasing 64-bit integer tracking global transaction order.
- **CRC32 Checksum**: Computed over payload bytes using standard IEEE 802.3 CRC32 polynomial. If bit corruption or partial writes occur, the checksum check fails and recovery isolates the bad record.

---

## 3. Crash Recovery and Replay Algorithm

On process startup, the `SnapshotManager` and `WriteAheadLog` execute recovery:

1. **Snapshot Loading**: Locate the latest snapshot file (`coffer.snap`). If present, restore the ledger chart of accounts and balances up to `lastSequenceNumber`.
2. **Sequential WAL Replay**: Open `coffer.wal`. Seek to the offset corresponding to `lastSequenceNumber + 1`.
3. **Checksum Verification**: For each binary frame, calculate CRC32 of payload and compare with header checksum.
4. **State Transition Application**: Re-apply committed journal batches into the ledger.
5. **Recovery Completion**: The engine transitions to healthy serving mode with zero data loss.

---

## 4. Cryptographic Binary Merkle Audit Trees

Every `JournalBatch` committed by the ledger engine generates an immutable SHA-256 Merkle root.

```
                   [Root Hash (SHA-256)]
                          /      \
             [Hash 0-1]              [Hash 2-3]
              /      \                /      \
          [Hash 0]  [Hash 1]      [Hash 2]  [Hash 3]
             |         |             |         |
          [Leaf 0]  [Leaf 1]      [Leaf 2]  [Leaf 3]
          (Entry 1) (Entry 2)     (Entry 3) (Entry 4)
```

- Individual ledger entries form the leaf nodes: $H_i = \text{SHA256}(\text{Entry}_i)$.
- Adjacent leaves are concatenated and hashed recursively: $H_{p} = \text{SHA256}(H_{\text{left}} \parallel H_{\text{right}})$.
- Odd leaf counts are balanced by duplicating the terminal node.
- The root hash is embedded into the journal batch header and published in `camt.053` bank statements, enabling third-party cryptographic verification.
