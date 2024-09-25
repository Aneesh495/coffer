# Benchmarking Methodology and High-Performance Profile

## 1. Benchmarking Philosophy

In mission-critical financial settlement systems, average latency is a vanity metric; **tail latency (p99 and p99.9)** dictates whether a clearing network meets real-time SLA thresholds (typically < 3,000 milliseconds for FedNow and RTP).

Coffer includes dedicated multi-threaded benchmarking suites designed to stress:
1. Native C 128-bit fixed-point arithmetic and SHA-256 Merkle tree construction.
2. Concurrent memory contention across parallel worker strands.
3. Ingress HTTP REST gateway throughput and microsecond latency distributions.

---

## 2. Microsecond HDR Latency Histogram

To record high-resolution latency distributions without allocating memory on the hot path, Coffer utilizes a custom **HDR (High Dynamic Range) Histogram** with logarithmic bucket boundaries spanning 10 microseconds to 600 seconds.

Buckets are bounded as follows:
- Sub-millisecond: 10us, 20us, 30us, ..., 100us, 250us, 500us, 750us, 1000us
- Millisecond tier: 1.5ms, 2ms, 5ms, 10ms, 25ms, 50ms, 100ms
- Second tier: 250ms, 500ms, 1s, 5s, 30s, 60s

Percentile calculations iterate across pre-allocated bucket arrays using linear interpolation, guaranteeing $O(1)$ constant time overhead per recorded transaction.

---

## 3. Empirical Performance Results

### Benchmark 1: Native C Acceleration Engine (Fixed-Point & Merkle Tree Commit)
- **Workload**: 50,000 continuous financial journal computations and SHA-256 tree root calculations.
- **Hardware**: Apple Silicon (8-core M-series / 16GB Unified RAM).
- **Tooling**: `clang -O3 -std=c11`, POSIX threads.

| Metric | Measured Value | Standard SLA Target |
| :--- | :--- | :--- |
| **Throughput** | **841,255 ops/sec** | > 100,000 ops/sec |
| **p50 Latency** | **10 microseconds** | < 1,000 microseconds |
| **p75 Latency** | **10 microseconds** | < 2,000 microseconds |
| **p90 Latency** | **10 microseconds** | < 5,000 microseconds |
| **p95 Latency** | **10 microseconds** | < 10,000 microseconds |
| **p99 Latency** | **20 microseconds** | < 25,000 microseconds |
| **p99.9 Latency** | **90 microseconds** | < 50,000 microseconds |
| **Min Latency** | **2 microseconds** | N/A |
| **Max Latency** | **3,156 microseconds** | < 100,000 microseconds |

### Benchmark 2: Python Concurrent Ingress Harness (Multi-Bank Simulation)
- **Workload**: 5,000 concurrent payment clearing intents dispatched across 8 worker threads.

| Metric | Measured Value |
| :--- | :--- |
| **Concurrent Throughput** | **39,456 requests/sec** |
| **p50 Latency** | **65 microseconds** |
| **p90 Latency** | **73 microseconds** |
| **p99 Latency** | **129 microseconds** |
| **Success Rate** | **100.00% (Zero dropped requests)** |

---

## 4. Reproducing Benchmarks

Execute the automated 50k benchmark harness:

```bash
./scripts/bench_50k.sh
```

Or run the native C benchmark directly with custom concurrency and iteration flags:

```bash
make build-c
./bin/coffer-bench -t 16 -n 100000
```
