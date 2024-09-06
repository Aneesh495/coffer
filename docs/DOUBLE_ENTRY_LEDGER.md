# Double-Entry Balanced Ledger Engine Specification

## 1. Accounting Philosophy and Invariant Bounds

Coffer implements a strict double-entry ledger adhering to standard GAAP and IFRS financial accounting standards.

The primary guarantee of the ledger engine is the **Zero-Sum Balance Invariant**:
Every financial movement across the system must be represented by an atomic `JournalBatch` containing at least two balanced entries (one debit and one credit leg), such that:

$$\sum_{i=1}^{N} \text{DebitAmount}_i \equiv \sum_{j=1}^{M} \text{CreditAmount}_j$$

If a batch is submitted where the sum of debits differs from the sum of credits by even one fractional cent, the engine immediately rejects the entire transaction with a typed `LedgerInvariantError` prior to modifying any account state.

```
+-----------------------------------------------------------------------------------+
|                            JOURNAL BATCH STRUCTURE                                |
+-----------------------------------------------------------------------------------+
| Batch ID        : BAT_9901_20261102                                               |
| Transaction ID  : TX_CHASE_BOFA_001                                               |
| Timestamp       : 1730550000000000 ns                                             |
| Status          : COMMITTED (Merkle Root: 7f83b1657ff1fc53b92dc18148a1d65dfc2d4) |
+-----------------------------------------------------------------------------------+
| Entry ID    | Account ID           | Direction | Amount     | Normal Balance Side |
+-------------+----------------------+-----------+------------+---------------------+
| ENT_001     | ACT_CHASE_SETTLEMENT | CREDIT    | $15,000.00 | Decreases Asset     |
| ENT_002     | ACT_BOFA_SETTLEMENT  | DEBIT     | $15,000.00 | Increases Asset     |
+-------------+----------------------+-----------+------------+---------------------+
| TOTALS      | Sum(Debits): $15,000.00   |   Sum(Credits): $15,000.00 | Delta: $0.00 |
+-------------+---------------------------+----------------------------+--------------+
```

---

## 2. Chart of Accounts Classification

Accounts registered in the Coffer chart of accounts are mapped to high-level accounting types with standard normal balance behaviors:

| Account Type | Normal Balance | Debit Effect | Credit Effect | Operational Example |
| :--- | :--- | :--- | :--- | :--- |
| **ASSET** | Debit | Increase (+) | Decrease (-) | Settlement Clearing, Central Bank Nostro, Customer Checking |
| **LIABILITY** | Credit | Decrease (-) | Increase (+) | Customer Deposits, Accounts Payable |
| **EQUITY** | Credit | Decrease (-) | Increase (+) | Capital Reserves, Retained Earnings |
| **REVENUE** | Credit | Decrease (-) | Increase (+) | Network Routing Fee Income |
| **EXPENSE** | Debit | Increase (+) | Decrease (-) | Partner Rail Processing Fees |

---

## 3. Escrow Hold and Available Balance Dynamics

To prevent double-spending during asynchronous payment clearance across external rails, the ledger decouples **Settled Balance** from **Available Balance**:

$$\text{AvailableBalance} = \text{SettledBalance} - \text{PendingHoldsBalance}$$

### Hold Lifecycle States:
1. **Hold Creation**: When a payment intent is accepted, an `AccountHold` record is instantiated. The requested amount is added to `pendingHoldsBalance`, instantly reducing `availableBalance`. `settledBalance` remains untouched.
2. **Hold Finalization**: Upon confirmation from the payment rail, `postBatch()` finalizes the hold. `pendingHoldsBalance` is decremented, and `settledBalance` is permanently debited.
3. **Hold Release (Compensation)**: If the payment rail rejects or times out, the saga initiates a rollback. `releaseHold()` clears the pending reservation, restoring `availableBalance` to its prior level without posting any journal entries.

---

## 4. Scaled Decimal Arithmetic and Bankers Rounding

Financial calculations must never use IEEE 754 floating-point numbers due to binary representation errors (e.g. `0.1 + 0.2 != 0.3`). Coffer employs `ScaledDecimal`, maintaining exact decimal integers with an 18-digit scale factor.

All division operations utilize **Bankers Rounding (Half-Even Rounding)**:
When a fractional value falls exactly on the midpoint (`.5`), it rounds to the nearest even digit:
- `2.5` rounds to `2`
- `3.5` rounds to `4`
- `4.5` rounds to `4`

This eliminates statistical bias across millions of automated transaction fee calculations.
