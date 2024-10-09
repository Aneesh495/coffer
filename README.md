# Coffer

[![CI Verification](https://github.com/Aneesh495/coffer/actions/workflows/ci.yml/badge.svg)](https://github.com/Aneesh495/coffer/actions)
[![Language: Ballerina](https://img.shields.io/badge/Ballerina-2201.14.1-20b6b0.svg)](https://ballerina.io)
[![Language: C11](https://img.shields.io/badge/Native%20Acceleration-C11-blue.svg)](https://en.cppreference.com/w/c/11)
[![Language: Python](https://img.shields.io/badge/SDK%20%26%20Sim-Python%203.11+-3776ab.svg)](https://python.org)
[![ISO Standard](https://img.shields.io/badge/Messaging-ISO%2020022-brightgreen.svg)](https://www.iso20022.org)
[![Invariant](https://img.shields.io/badge/Double--Entry-Zero--Sum%20Strict-orange.svg)](docs/DOUBLE_ENTRY_LEDGER.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Coffer is a high-assurance distributed payment orchestration, real-time clearing, and multi-rail liquidity settlement fabric. Engineered with Ballerina as its concurrency star and reinforced with native C mathematical acceleration, Coffer unifies domestic instant payment rails (FedNow, The Clearing House RTP, SEPA Instant), batch clearing networks (ACH), and interbank financial messaging (SWIFT ISO 20022).

---

## Architecture Overview

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

## Key Subsystems

### 1. High-Assurance Double-Entry Balanced Ledger
- Full GAAP and IFRS chart of accounts classification (Assets, Liabilities, Equity, Revenue, Expense).
- Strict Zero-Sum Conservation Invariant: Every journal batch enforces $\sum \text{Debits} \equiv \sum \text{Credits}$.
- Decoupled `availableBalance` and `settledBalance` via atomic two-phase escrow holds to eliminate double-spending risks.
- Exact 128-bit scaled decimal math with Bankers Rounding (Half-Even) to prevent floating-point drift.
- Read more: [Double-Entry Ledger Specification](docs/DOUBLE_ENTRY_LEDGER.md).

### 2. ISO 20022 Financial Messaging Engine
- Native serialization, parsing, and structural validation of:
  - `pacs.008.001.10`: Financial Institutional Customer Credit Transfer.
  - `pacs.002.001.12`: Real-time Payment Status Report (ACCP, ACTC, RJCT, PDNG).
  - `camt.053.001.10`: Bank-to-Customer End-of-Day Account Statement.
- Automated schema normalization and BIC/IBAN validation.
- Read more: [ISO 20022 Specification](docs/ISO20022_SPECIFICATION.md).

### 3. Distributed Saga Orchestration and Automated Compensation
- Forward clearance lifecycle coordinating idempotency, risk scoring, route selection, escrow holds, and rail dispatch.
- Automated backward recovery: If an external rail times out or fails, compensating transactions release escrow reservations without leaking state.
- Cryptographic idempotency store guaranteeing Exactly-Once Semantics across client submissions.
- Read more: [Saga Orchestration](docs/SAGA_ORCHESTRATION.md).

### 4. Multilateral Netting and Intraday Liquidity Optimization
- Mathematical cycle cancellation algorithm reducing gross payment streams to single net bilateral positions.
- Formal zero-sum netting proof: $\sum_{i} \text{NetPosition}_i \equiv 0.00$.
- Demonstrated 95%+ liquidity savings ratio, dramatically reducing intraday central bank reserve requirements.
- Dynamic bilateral unwinding mechanism that contains participant default contagion.
- Read more: [Liquidity Netting Specification](docs/LIQUIDITY_NETTING.md).

### 5. Real-Time Risk, Sanctions Screening, and Quarantine Store
- Token-boundary OFAC Sanctions screening eliminating substring false positives.
- Sliding-window velocity tracking measuring hourly frequency and gross volume per account.
- Integrated Quarantine State Machine enabling dual-control compliance analyst review.
- Read more: [Risk and Fraud Engine](docs/RISK_AND_FRAUD.md).

### 6. Storage Durability, WAL, and SHA-256 Merkle Trees
- High-durability Append-Only Write-Ahead Log (WAL) with length-prefixed frames and IEEE 802.3 CRC32 checksums.
- Point-in-time state snapshots bounding crash recovery replay.
- RFC 6234 compliant SHA-256 binary Merkle audit trees providing cryptographic proof of journal inclusion.
- Read more: [WAL and Merkle Trees](docs/WAL_AND_MERKLE.md).

---

## High-Performance Profile

Coffer features native C acceleration libraries (`c_src/`) for computationally intensive fixed-point arithmetic and Merkle tree calculations. Tail latency distributions are captured using a microsecond HDR histogram.

| Subsystem Workload | Concurrency | Measured Throughput | p50 Latency | p99 Latency | p99.9 Latency |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Native C Fixed-Point & Merkle Tree Commit** | 8 worker threads | **841,255 ops/sec** | **10 us** | **20 us** | **90 us** |
| **Python Concurrent Ingress Simulator** | 8 worker threads | **39,456 tx/sec** | **65 us** | **129 us** | **4.1 ms** |
| **Multilateral Netting Cycle (1,200 debts)** | Single-pass matrix | **1,200 debts in 3ms** | **95.5% Liquidity Savings** | **Zero-Sum Verified** | N/A |

Read the full empirical methodology: [Benchmarking and Performance Report](docs/BENCHMARKING_AND_PERFORMANCE.md).

---

## Quickstart Guide

### 1. Prerequisites
- **Ballerina**: 2201.14.1 (Swan Lake Update 14) or newer.
- **Clang/GCC**: Supporting C11.
- **Python**: 3.10+ (standard library only).

### 2. Build Native Acceleration Libraries and Run Tests
```bash
# Clone repository
git clone https://github.com/Aneesh495/coffer.git
cd coffer

# Build native C acceleration libraries and verify em dash compliance
make build-c
make check-dashes

# Run full Ballerina and native test suites
bal test
```

### 3. Launch Development Payment Gateway
```bash
./scripts/dev_run.sh
```
The gateway initializes on:
- HTTP REST API Gateway: `http://127.0.0.1:8990`
- WebSocket Real-time Feed: `ws://127.0.0.1:8991`
- Admin Reconciliation API: `http://127.0.0.1:8992`
- Prometheus Metrics Exporter: `http://127.0.0.1:8990/metrics`

### 4. Run Multi-Bank Network Simulation
```bash
./scripts/simulate_network.sh 1000
```

### 5. Run 50k Transaction Performance Benchmark
```bash
./scripts/bench_50k.sh
```

### 6. Master Verification (Zero-Defect Quality Check)
```bash
./scripts/verify_all.sh
```

---

## Technical Documentation Catalog

- [System Architecture Specification](docs/ARCHITECTURE.md)
- [Double-Entry Balanced Ledger Engine](docs/DOUBLE_ENTRY_LEDGER.md)
- [ISO 20022 Financial Messaging Dictionary](docs/ISO20022_SPECIFICATION.md)
- [Distributed Saga Orchestrator](docs/SAGA_ORCHESTRATION.md)
- [Multilateral Netting and Liquidity Optimization](docs/LIQUIDITY_NETTING.md)
- [Real-Time Risk, Sanctions, and Quarantine](docs/RISK_AND_FRAUD.md)
- [Write-Ahead Logging, Snapshots, and Merkle Trees](docs/WAL_AND_MERKLE.md)
- [Benchmarking Methodology and Profile](docs/BENCHMARKING_AND_PERFORMANCE.md)
- [HTTP REST and WebSocket API Reference](docs/API_REFERENCE.md)
- [Zero-Defect Verification and Regression History](docs/VERIFICATION_AND_REGRESSIONS.md)
- [Production Deployment and Operations Guide](docs/DEPLOYMENT_AND_OPERATIONS.md)
- [Developer and Contributor Manual](docs/DEVELOPER_GUIDE.md)

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
