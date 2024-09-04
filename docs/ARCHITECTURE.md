# Coffer System Architecture and Distributed Fabric Specification

## 1. Executive Summary

Coffer is a high-assurance, distributed payment orchestration and liquidity settlement engine engineered to bridge real-time payment rails (FedNow, SEPA Instant, The Clearing House RTP), domestic clearing houses (ACH), and interbank messaging networks (SWIFT ISO 20022).

The core engine is built in Ballerina, leveraging its native cloud-first concurrency model, isolated execution contexts, and typed network protocols. Compute-intensive primitives (128-bit scaled decimal arithmetic, multilateral netting graph cancellation, and binary Merkle audit tree hashing) are reinforced with native C acceleration routines.

```
 +-------------------------------------------------------------------------------+
 |                       COFFER INGRESS & GATEWAY LAYER                          |
 |                                                                               |
 |   +------------------------+  +-------------------+  +--------------------+   |
 |   |   HTTP/REST Gateway    |  |  WebSocket Event  |  |   Reconciliation   |   |
 |   |   (Port 8990)          |  |  Stream (8991)    |  |   Admin (8992)     |   |
 |   +-----------+------------+  +---------+---------+  +---------+----------+   |
 +---------------|-------------------------|----------------------|--------------+
                 |                         |                      |
 +---------------v-------------------------v----------------------v--------------+
 |                  DISTRIBUTED SAGA CLEARING ORCHESTRATOR                       |
 |                                                                               |
 |   [Step 1: Idempotency & Ingress Dedup]                                       |
 |                      |                                                        |
 |   [Step 2: Real-Time Risk & OFAC Sanctions Gatekeeper]                        |
 |                      |                                                        |
 |   [Step 3: Dynamic Multi-Rail Router & SLA Cost Optimizer]                    |
 |                      |                                                        |
 |   [Step 4: Atomic Double-Entry Ledger Escrow Reservation]                     |
 |                      |                                                        |
 |   [Step 5: External Rail Dispatch & Settlement Handshake]                     |
 |                      |                                                        |
 |   [Step 6: Journal Batch Finalization & Merkle WAL Commit]                    |
 |                      |                                                        |
 |                      +-----> [Automated Compensation Rollback on Failure]     |
 +-------------------------------------------------------------------------------+
                 |                                                |
 +---------------v----------------+             +-----------------v--------------+
 |  DOUBLE-ENTRY LEDGER ENGINE    |             |  LIQUIDITY NETTING OPTIMIZER   |
 |  - Strict Zero-Sum Invariant   |             |  - Multilateral Cycle Canceller|
 |  - Chart of Accounts (GAAP)    |             |  - Collateral Margin Check     |
 |  - Atomic Escrow Holds         |             |  - 95%+ Intraday Liquidity Save|
 +--------------------------------+             +--------------------------------+
                 |                                                |
 +---------------v------------------------------------------------v--------------+
 |                   DURABILITY & AUDIT STORAGE SUBSYSTEM                        |
 |  - Append-Only Write-Ahead Log (WAL) with CRC32 Chunk Integrity               |
 |  - Periodic State Snapshots & Instant Crash Recovery Replay                   |
 |  - Cryptographic Binary Merkle Tree with RFC 6234 SHA-256 Audit Roots         |
 +-------------------------------------------------------------------------------+
```

---

## 2. Distributed Clearing Pipeline

Every payment transaction processed by Coffer traverses a deterministic, state-machine validated sequence of lifecycle stages:

```
  [INITIATED] --------> [RISK_ASSESSED] --------> [ROUTED]
                              |                      |
                        (quarantined)          (no route)
                              |                      |
                              v                      v
                       [QUARANTINED]            [REJECTED]
                              |
                        (approv/reject)
                              |
                              +--------> [RESERVED] --------> [DISPATCHED]
                                              |                      |
                                        (funds error)          (rail timeout)
                                              |                      |
                                              v                      v
                                         [REJECTED]           [COMPENSATING]
                                                                     |
                                                                     v
                                                               [COMPENSATED]
                                                                     |
                                                         (successful dispatch)
                                                                     |
                                                                     v
                                                                 [SETTLED]
```

### 2.1 Forward Execution Phases

1. **Ingress and Cryptographic Deduplication**:
   Client submissions must supply a unique `X-Idempotency-Key`. The gateway validates key unicity in memory. If a submission with an identical key and matching payload arrives, the cached final settlement response is immediately returned without re-executing ledger mutations. If the key matches but the transfer parameters diverge, an `IdempotencyConflictError` is raised.

2. **Compliance, Sanctions, and Risk Gatekeeping**:
   Before initiating ledger operations, debtor and creditor identities are cross-checked against OFAC Specially Designated Nationals (SDN) lists using word-boundary token matching. In parallel, a sliding-window velocity tracker examines transaction frequency and gross volume within a rolling 60-minute window. Transactions flagged with high anomaly scores are diverted to the `QUARANTINED` state awaiting analyst review.

3. **Dynamic Rail Selection**:
   The multi-rail router scores eligible settlement rails (FedNow, SEPA Instant, RTP, ACH, SWIFT) based on:
   - Target currency and geographical jurisdiction.
   - Operating status and circuit-breaker trip health.
   - p99 clearing latency versus customer transaction deadline.
   - Projected settlement fee in basis points.

4. **Double-Entry Escrow Hold**:
   An atomic hold is placed on the debtor account, decrementing `availableBalance` while preserving `settledBalance`. This prevents double-spending while external dispatch proceeds.

5. **External Rail Dispatch**:
   The payment payload is formatted into standard ISO 20022 XML (`pacs.008.001.10`) and dispatched to the target clearing network interface.

6. **Journal Batch Commitment & WAL Logging**:
   Upon receipt of positive settlement confirmation (`pacs.002.001.12`), the escrow hold is released, settled balances are updated across debtor and creditor accounts, an immutable `JournalBatch` is generated, and a CRC32-checksummed entry is appended to the Write-Ahead Log.

---

## 3. Concurrency and Isolation Model

Ballerina 2201 introduces rigorous compiler-enforced thread isolation rules:
- **State Encapsulation**: Shared engine states (Ledger, Risk, Router, Storage) are encapsulated within `isolated` class instances.
- **Lock Concurrency**: State mutations occur within scoped `lock { ... }` blocks, preventing data races without global mutex contention.
- **Readonly Constants**: Global configuration tables, currency registries, and latency bucket bounds are declared as `final readonly & T[]`, enabling lock-free concurrent reads across worker strands.
