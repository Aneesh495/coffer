# Real-Time Risk, Sanctions Screening, and Quarantine Architecture

## 1. Compliance Architecture

Coffer embeds an inline compliance gatekeeper that evaluates every transaction prior to ledger reservation. The compliance engine enforces three independent layers of defense:

1. **OFAC Sanctions & Blocked Persons Screening**:
   Scans debtor and creditor party names against international sanctions databases (OFAC SDN, EU Consolidated Financial Sanctions).
2. **Real-Time Sliding-Window Velocity Tracking**:
   Monitors high-frequency burst patterns and aggregate hourly volume per account to prevent mule account exploitation.
3. **Quarantine State Machine**:
   Flagged transactions are isolated into an administrative holding area (`QuarantineStore`) awaiting dual-control analyst approval or rejection.

```
       INCOMING PAYMENT INTENT
                  |
                  v
       [Layer 1: OFAC Sanctions] ----(match)----> [REJECTED (Score: 100)]
                  |
                  v (clean)
       [Layer 2: Velocity Tracker]
       - Hourly tx count > 20   (+35 pts)
       - Hourly volume > $50k   (+30 pts)
       - Single tx > $500k      (+40 pts)
                  |
                  v
       Composite Risk Score (0-100)
                  |
       +----------+----------+
       |                     |
     < 50                  >= 50
       |                     |
       v                     v
   [APPROVED]          [QUARANTINED]
       |                     |
(Proceed to Rail)     (Admin Review: Approve / Reject)
```

---

## 2. Token-Boundary Sanctions Matching

A naive substring search for sanctions matching leads to severe false positives. For example, searching for `"Alice"` within `"VIKTOR MALICE DRUG CARTEL"` would yield a substring match because `"MALICE".contains("ALICE") == true`.

Coffer eliminates this defect by tokenizing both the target name and the sanctioned registry into discrete uppercase words and evaluating exact token or whole-phrase boundary matches:

```ballerina
// Token boundary screening algorithm
string[] queryTokens = splitTokens(cleanName);
foreach SanctionEntry entry in registry {
    if entry.tokens.includesAll(queryTokens) {
        return entry; // True positive match
    }
}
```

---

## 3. Sliding-Window Velocity Algorithm

Velocity is monitored across individual accounts using in-memory monotonic timestamps:

$$\text{HourlyVolume}(A, T) = \sum_{e \in E_A \land (T - t_e) \le 1 \text{ hour}} \text{Amount}(e)$$

$$\text{HourlyCount}(A, T) = |\{ e \in E_A \mid (T - t_e) \le 1 \text{ hour} \}|$$

Events older than the window threshold are pruned during lookup, maintaining bounded $O(K)$ space per active account where $K$ is the number of events in the trailing hour.

---

## 4. Quarantine Store FSM

When an intent exceeds risk score thresholds, it transitions into `QuarantinedItem`:
- **PENDING_REVIEW**: Funds are reserved but not dispatched. The client receives a `202 Accepted` response with status `QUARANTINED`.
- **RELEASED**: A compliance officer approves the case via the Admin Reconciliation API (`POST /api/v1/quarantine/{id}/review`). The orchestrator resumes forward saga execution.
- **REJECTED**: Compliance denies the case. The held funds are released back to the debtor account, and an audit alert is logged.
