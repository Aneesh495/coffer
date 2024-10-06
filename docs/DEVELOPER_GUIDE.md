# Coffer Developer Guide and Contributor Manual

## 1. Local Workspace Initialization

### Prerequisites:
- Ballerina 2201.14.1 (Swan Lake Update 14) or newer.
- Clang or GCC with C11 support.
- Python 3.10+ for SDK and simulator tools.
- Git and Make.

### Cloning and Verification:
```bash
git clone https://github.com/Aneesh495/coffer.git
cd coffer

# Build native C acceleration libraries and verify dash compliance
make build-c
make check-dashes

# Execute the complete master verification suite
./scripts/verify_all.sh
```

---

## 2. Repository Layout

```
coffer/
├── Ballerina.toml              # Master Ballerina package manifest
├── Dependencies.toml           # Locked package dependencies
├── Makefile                    # Build, test, and verification automation
├── coffer.conf.example         # System configuration template
├── main.bal                    # Gateway daemon entrypoint
├── service_http.bal            # REST API service (Port 8990)
├── service_ws.bal              # WebSocket event feed (Port 8991)
├── service_admin.bal           # Admin reconciliation service (Port 8992)
├── modules/
│   ├── types/                  # Domain schemas, ISO currencies, typed errors
│   ├── fixedpoint/             # 128-bit scaled decimal math & Bankers rounding
│   ├── ledger/                 # GAAP double-entry chart of accounts & holds
│   ├── iso20022/               # pacs.008, pacs.002, camt.053 XML serializers
│   ├── routing/                # Multi-rail selector & circuit breaker failover
│   ├── risk/                   # Velocity tracking, OFAC screening, quarantine
│   ├── saga/                   # Distributed Saga orchestrator & compensations
│   ├── netting/                # Multilateral netting cycle optimizer
│   ├── storage/                # Append-only WAL, Merkle trees, state snapshots
│   └── telemetry/              # HDR microsecond histogram & OpenMetrics exporter
├── c_src/
│   ├── fixedpoint/             # Native C 128-bit scaled decimal engine
│   ├── netting/                # Native C multilateral netting graph canceller
│   ├── merkle/                 # Native C RFC 6234 SHA-256 Merkle tree engine
│   └── bench/                  # Native C pthread multi-threaded benchmark
├── python/
│   ├── coffer_sdk/             # Python HTTP REST client and data models
│   ├── simulator/              # 10-Bank interbank & liquidity stress simulators
│   ├── bench/                  # High-concurrency Python load test generator
│   └── tests/                  # Unit test suite for Python modules
├── tests/
│   ├── test_regressions.bal    # 5 documented bug regression tests
│   ├── test_integration_*.bal  # End-to-end integration test scenarios
│   ├── integration/            # Integration shell harness
│   └── regressions/            # Regression shell harness
├── scripts/
│   ├── dev_run.sh              # Local development daemon runner
│   ├── simulate_network.sh     # Network simulation runner
│   ├── bench_50k.sh            # 50,000 transaction benchmark harness
│   └── verify_all.sh           # Master multi-language verification suite
└── docs/                       # Technical architecture & subsystem manuals
```

---

## 3. Contribution Workflow

1. Always execute `make verify` before committing changes.
2. Ensure every bug encountered is preserved as a permanent regression test.
3. Strict constraint: Never use em or en dashes in any code, comment, or documentation file.
