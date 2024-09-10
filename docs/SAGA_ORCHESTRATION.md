# Distributed Saga Orchestration and Automated Compensation Fabric

## 1. Saga Architecture Principles

Cross-rail interbank payment clearance cannot rely on traditional Two-Phase Commit (2PC) protocols because external payment networks (FedNow, RTP, SEPA Instant) do not participate in distributed database locking.

Coffer addresses this with an asynchronous **Orchestrated Saga Pattern**:
A sequence of discrete local transactions coordinated by `PaymentSagaOrchestrator`. Each forward step is paired with an idempotent compensating action that reverses previously committed mutations if downstream steps fail.

```
       FORWARD EXECUTION STAGES                     COMPENSATION ROLLBACK PATHS
       
 [Step 1: Idempotency Deduplication]  --------->  (No side effects; abort cleanly)
                  |
 [Step 2: Risk & Sanctions Scoring]   --------->  (Log rejection event; exit)
                  |
 [Step 3: Route Selection & SLA Cap]  --------->  (Trip circuit breaker on failure)
                  |
 [Step 4: Ledger Escrow Reservation]  --------->  [Comp 1: Release Escrow Hold]
                  |                                             ^
 [Step 5: External Rail Dispatch]     ----(timeout/failure)----+
                  |
 [Step 6: Journal Batch Commitment]   --------->  (Terminal settlement reached)
```

---

## 2. Forward Clearing Steps and Compensations

| Step | Action Performed | State Mutation | Compensating Action |
| :--- | :--- | :--- | :--- |
| **1. Idempotency Check** | Lookup client `X-Idempotency-Key` in memory cache | None | None |
| **2. Risk Screening** | Check OFAC lists & hourly velocity thresholds | Updates velocity counters | Mark transaction `REJECTED` |
| **3. Route Selection** | Rank rails by SLA, latency, and cost | None | Select next fallback rail |
| **4. Escrow Hold** | Reserve debtor spendable funds | Increments `pendingHoldsBalance` | `releaseHold()` restores available balance |
| **5. Rail Dispatch** | Post `pacs.008` XML to payment network | Sets status `DISPATCHED` | Trigger rail reversal or initiate Step 4 rollback |
| **6. Ledger Commit** | Post balanced `JournalBatch` | Mutates `settledBalance` | Post reverse journal batch (chargeback / refund) |

---

## 3. Idempotency Guarantees

Every transfer intent submitted to Coffer requires an idempotency key.
The orchestrator maintains an index mapping `idempotencyKey -> transactionId`:

```
Client Request (Key: "abc-123")
        |
        v
+-------------------------------+
| Idempotency Key in Store?     |
+---------------+---------------+
                |
       +--------+--------+
       | YES             | NO
       v                 v
+---------------+  +-----------------------------+
| Same Payload? |  | Execute Saga Forward Steps  |
+-------+-------+  +-----------------------------+
        |
   +----+----+
   | YES     | NO
   v         v
+-------+  +-------------------------------------+
| Return|  | Return IdempotencyConflictError     |
| Cached|  | (Different amount, currency, orBIC) |
| Result|  +-------------------------------------+
+-------+
```

This guarantees **Exactly-Once Semantics** from the perspective of client applications.
