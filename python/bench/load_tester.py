"""
High-concurrency load testing harness for Coffer Payment Orchestrator.
Spawns concurrent worker threads to evaluate HTTP ingress throughput,
microsecond latency distributions, and circuit-breaker behavior.
"""

import sys
import time
import uuid
import argparse
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any, Optional

from coffer_sdk.models import Institution, Party, TransferRequest
from coffer_sdk.client import CofferClient, CofferApiError

BANKS = [
    Institution(bic="CHASUS33XXX", name="JPMorgan Chase Bank N.A.", country="US"),
    Institution(bic="BOFAUS3NXXX", name="Bank of America N.A.", country="US"),
    Institution(bic="CITIUS33XXX", name="Citibank N.A.", country="US"),
    Institution(bic="WFBIUS6SXXX", name="Wells Fargo Bank N.A.", country="US"),
]


class LoadTester:
    """
    Multi-threaded load generator measuring latency percentiles and throughput.
    """

    def __init__(self, base_url: str = "http://127.0.0.1:8990", use_mock: bool = False):
        self.base_url = base_url
        self.use_mock = use_mock
        self.client = CofferClient(base_url=base_url) if not use_mock else None
        self.latencies_us: List[int] = []
        self.lock = threading.Lock()
        self.success_count = 0
        self.failure_count = 0

    def _execute_single_transfer(self, idx: int) -> bool:
        debtor_bank = BANKS[idx % len(BANKS)]
        creditor_bank = BANKS[(idx + 1) % len(BANKS)]
        amount = f"{(100.0 + (idx % 500) * 1.5):.2f}"

        req = TransferRequest(
            idempotency_key=f"BENCH-{uuid.uuid4()}",
            debtor=Party(account_id=f"ACT-{debtor_bank.bic}-USD", institution=debtor_bank),
            creditor=Party(account_id=f"ACT-{creditor_bank.bic}-USD", institution=creditor_bank),
            currency="USD",
            amount=amount,
            memo=f"Load test batch item {idx}"
        )

        start = time.perf_counter_ns()
        ok = False

        if self.use_mock:
            # Simulate in-memory processing
            time.sleep(0.00005) # 50 microseconds
            ok = True
        else:
            try:
                self.client.execute_transfer(req)
                ok = True
            except (CofferApiError, Exception):
                ok = False

        elapsed_us = (time.perf_counter_ns() - start) // 1000
        if elapsed_us <= 0:
            elapsed_us = 1

        with self.lock:
            self.latencies_us.append(elapsed_us)
            if ok:
                self.success_count += 1
            else:
                self.failure_count += 1

        return ok

    def run(self, total_requests: int = 5000, concurrency: int = 16):
        print(f"Executing Load Test: {total_requests} requests across {concurrency} threads (mock={self.use_mock})...")
        self.latencies_us.clear()
        self.success_count = 0
        self.failure_count = 0

        start_time = time.time()

        with ThreadPoolExecutor(max_workers=concurrency) as executor:
            futures = [executor.submit(self._execute_single_transfer, i) for i in range(total_requests)]
            for f in as_completed(futures):
                pass

        duration = time.time() - start_time
        self.print_report(total_requests, concurrency, duration)

    def print_report(self, total_ops: int, concurrency: int, duration_sec: float):
        throughput = total_ops / duration_sec if duration_sec > 0 else 0
        sorted_lat = sorted(self.latencies_us)

        def pct(p: float) -> int:
            if not sorted_lat:
                return 0
            idx = int(len(sorted_lat) * (p / 100.0))
            idx = min(idx, len(sorted_lat) - 1)
            return sorted_lat[idx]

        print("\n================================================================================")
        print(" COFFER HTTP REST GATEWAY LOAD TEST REPORT")
        print("================================================================================")
        print(f" Concurrency Level       : {concurrency} workers")
        print(f" Total Requests Sent     : {total_ops}")
        print(f" Successful Clearances   : {self.success_count} ({self.success_count / (total_ops or 1) * 100:.2f}%)")
        print(f" Rejected / Failed       : {self.failure_count}")
        print(f" Benchmark Duration      : {duration_sec:.4f} seconds")
        print(f" Aggregated Throughput   : {throughput:.2f} requests/second")
        print("--------------------------------------------------------------------------------")
        print(" Ingress Latency Distribution:")
        print(f"   p50 (Median)          : {pct(50.0):>8} us ({pct(50.0) / 1000.0:.2f} ms)")
        print(f"   p75                   : {pct(75.0):>8} us ({pct(75.0) / 1000.0:.2f} ms)")
        print(f"   p90                   : {pct(90.0):>8} us ({pct(90.0) / 1000.0:.2f} ms)")
        print(f"   p95                   : {pct(95.0):>8} us ({pct(95.0) / 1000.0:.2f} ms)")
        print(f"   p99                   : {pct(99.0):>8} us ({pct(99.0) / 1000.0:.2f} ms)")
        print(f"   p99.9                 : {pct(99.9):>8} us ({pct(99.9) / 1000.0:.2f} ms)")
        print(f"   Min Latency           : {sorted_lat[0] if sorted_lat else 0:>8} us")
        print(f"   Max Latency           : {sorted_lat[-1] if sorted_lat else 0:>8} us")
        print("================================================================================")


def main():
    parser = argparse.ArgumentParser(description="Coffer Gateway Load Tester")
    parser.add_argument("--requests", "-n", type=int, default=2000, help="Total requests to dispatch")
    parser.add_argument("--concurrency", "-c", type=int, default=8, help="Number of concurrent worker threads")
    parser.add_argument("--mock", action="store_true", help="Run with local mock engine")
    parser.add_argument("--url", default="http://127.0.0.1:8990", help="Coffer gateway REST URL")
    args = parser.parse_args()

    tester = LoadTester(base_url=args.url, use_mock=args.mock)
    tester.run(total_requests=args.requests, concurrency=args.concurrency)


if __name__ == "__main__":
    main()
