# Coffer HTTP REST and Streaming API Reference

The Coffer Payment Orchestration Gateway provides three primary network services:
1. **HTTP REST Gateway API** (`http://127.0.0.1:8990`): Core payment ingress, accounts, and netting.
2. **WebSocket Event Stream** (`ws://127.0.0.1:8991`): Real-time clearing event feed.
3. **Admin Reconciliation API** (`http://127.0.0.1:8992`): Internal ledger reconciliation and audit inspection.

---

## 1. REST Gateway Endpoints (Port 8990)

### 1.1 POST /api/v1/transfers
Submits a payment transfer intent for end-to-end clearing and settlement.

**Headers:**
- `Content-Type: application/json`
- `X-Idempotency-Key: string` (Mandatory for deduplication)

**Request Body:**
```json
{
  "idempotency_key": "IDEMP-20261102-001",
  "debtor": {
    "account_id": "ACT_CHASE_01",
    "institution": {
      "bic": "CHASUS33XXX",
      "name": "JPMorgan Chase Bank N.A.",
      "country": "US"
    }
  },
  "creditor": {
    "account_id": "ACT_BOFA_01",
    "institution": {
      "bic": "BOFAUS3NXXX",
      "name": "Bank of America N.A.",
      "country": "US"
    }
  },
  "currency": "USD",
  "amount": "15000.00",
  "charge_bearer": "SLEV",
  "memo": "Treasury interbank transfer",
  "preferred_rail": "FEDNOW"
}
```

**Response (200 OK):**
```json
{
  "payment_id": "tx_e2e_clear_001",
  "idempotency_key": "IDEMP-20261102-001",
  "state": "SETTLED",
  "selected_rail": "FEDNOW",
  "cleared_at": 1730550001000000,
  "settlement_reference": "RAIL_REF_tx_e2e_clear_001_FEDNOW",
  "message": "Payment cleared and settled successfully"
}
```

---

### 1.2 GET /api/v1/accounts/{id}
Retrieves account balance snapshots and state.

**Response (200 OK):**
```json
{
  "id": "ACT_CHASE_01",
  "bic": "CHASUS33XXX",
  "currency": "USD",
  "category": "CUSTOMER_CHECKING",
  "settled_balance": "235000.00",
  "held_balance": "0.00",
  "available_balance": "235000.00",
  "is_active": true
}
```

---

### 1.3 POST /api/v1/quarantine/{caseId}/review
Submits a compliance decision (APPROVE or REJECT) for a quarantined payment intent.

**Request Body:**
```json
{
  "decision": "APPROVE",
  "notes": "Verified source of wealth documentation"
}
```

---

### 1.4 POST /api/v1/netting/cycles
Executes a multilateral netting optimization cycle across a batch of bilateral obligations.

**Request Body:**
```json
{
  "obligations": [
    {
      "obligation_id": "OBL-001",
      "debtor_bic": "CHASUS33XXX",
      "creditor_bic": "BOFAUS3NXXX",
      "currency": "USD",
      "amount": "3000000.00"
    },
    {
      "obligation_id": "OBL-002",
      "debtor_bic": "BOFAUS3NXXX",
      "creditor_bic": "CITIUS33XXX",
      "currency": "USD",
      "amount": "2500000.00"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "cycle_id": "CYCLE-20261102-01",
  "total_gross_obligations": 2,
  "gross_volume": "5500000.00",
  "net_settlement_volume": "3000000.00",
  "liquidity_savings_ratio": 45.45,
  "is_balanced": true
}
```

---

### 1.5 GET /metrics
Returns real-time telemetry formatted for Prometheus / OpenMetrics scraping:

```
# HELP coffer_transfers_total Total transfer requests processed by gateway
# TYPE coffer_transfers_total counter
coffer_transfers_total{status="SETTLED",rail="FEDNOW"} 14820
coffer_transfers_total{status="SETTLED",rail="RTP"} 8912

# HELP coffer_transfer_latency_us Microsecond transfer latency distribution
# TYPE coffer_transfer_latency_us histogram
coffer_transfer_latency_us_bucket{le="10"} 12400
coffer_transfer_latency_us_bucket{le="50"} 21300
coffer_transfer_latency_us_bucket{le="100"} 23500
coffer_transfer_latency_us_bucket{le="+Inf"} 23732
coffer_transfer_latency_us_count 23732
```

---

## 2. WebSocket Event Streaming (Port 8991)

Clients establish a persistent WebSocket connection to `ws://127.0.0.1:8991` to receive real-time JSON push events:

```json
{
  "event_type": "PAYMENT_SETTLED",
  "timestamp_ns": 1730550001000000,
  "payload": {
    "payment_id": "tx_e2e_clear_001",
    "rail": "FEDNOW",
    "amount": "15000.00",
    "currency": "USD",
    "journal_batch_id": "BAT_tx_e2e_clear_001"
  }
}
```
