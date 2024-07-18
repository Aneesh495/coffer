"""
Multi-Bank Clearing Network Simulator.
Simulates a high-velocity interbank clearing fabric with 10 commercial banks,
Pareto-distributed payment amounts, and multi-rail settlement routing.
"""

import sys
import time
import random
import uuid
import argparse
from typing import List, Dict, Any, Optional

from coffer_sdk.models import (
    Institution,
    Party,
    TransferRequest,
    Currency,
    PaymentRail,
)
from coffer_sdk.client import CofferClient, CofferApiError

PARTICIPATING_BANKS = [
    Institution(bic="CHASUS33XXX", name="JPMorgan Chase Bank N.A.", country="US"),
    Institution(bic="BOFAUS3NXXX", name="Bank of America N.A.", country="US"),
    Institution(bic="CITIUS33XXX", name="Citibank N.A.", country="US"),
    Institution(bic="WFBIUS6SXXX", name="Wells Fargo Bank N.A.", country="US"),
    Institution(bic="BNPAFRPPXXX", name="BNP Paribas S.A.", country="FR"),
    Institution(bic="DEUTDEDDXXX", name="Deutsche Bank AG", country="DE"),
    Institution(bic="HSBCGB2LXXX", name="HSBC Bank plc", country="GB"),
    Institution(bic="BARCGB22XXX", name="Barclays Bank UK PLC", country="GB"),
    Institution(bic="SANBESMMAXX", name="Banco Santander S.A.", country="ES"),
    Institution(bic="SCBLSG22XXX", name="Standard Chartered Bank (Singapore)", country="SG"),
]


class LocalMockEngine:
    """
    In-memory simulation engine for fast headless execution without a live daemon.
    """

    def __init__(self):
        self.accounts: Dict[str, float] = {}
        for b in PARTICIPATING_BANKS:
            self.accounts[f"ACT-{b.bic}-USD"] = 100_000_000.00
            self.accounts[f"ACT-{b.bic}-EUR"] = 100_000_000.00
        self.cleared_count = 0
        self.total_volume = 0.0

    def transfer(self, req: TransferRequest) -> Dict[str, Any]:
        amount = float(req.amount)
        debtor_act = req.debtor.account_id
        creditor_act = req.creditor.account_id

        if self.accounts.get(debtor_act, 0.0) < amount:
            return {"status": "REJECTED", "reason": "Insufficient balance"}

        self.accounts[debtor_act] -= amount
        self.accounts[creditor_act] = self.accounts.get(creditor_act, 0.0) + amount
        self.cleared_count += 1
        self.total_volume += amount

        rail = req.preferred_rail or "FEDNOW"
        return {
            "payment_id": f"PMT-{uuid.uuid4().hex[:12]}",
            "state": "SETTLED",
            "selected_rail": rail,
            "settlement_reference": f"SETTL-{uuid.uuid4().hex[:8]}"
        }


class BankNetworkSimulator:
    """
    Orchestrates synthetic interbank clearing flow and measures throughput.
    """

    def __init__(self, client: Optional[CofferClient] = None, use_mock: bool = False):
        self.client = client
        self.use_mock = use_mock
        self.mock_engine = LocalMockEngine() if use_mock else None

    def generate_random_transfer(self) -> TransferRequest:
        debtor_bank, creditor_bank = random.sample(PARTICIPATING_BANKS, 2)
        curr = random.choice([Currency.USD, Currency.EUR])

        # Pareto distribution for realistic payment sizes (many small, few large)
        base_amt = (random.paretovariate(1.8) * 150.0)
        clamped_amt = max(10.0, min(base_amt, 500000.0))
        amount_str = f"{clamped_amt:.2f}"

        debtor = Party(
            account_id=f"ACT-{debtor_bank.bic}-{curr.value}",
            institution=debtor_bank
        )
        creditor = Party(
            account_id=f"ACT-{creditor_bank.bic}-{curr.value}",
            institution=creditor_bank
        )

        return TransferRequest(
            idempotency_key=f"SIM-{uuid.uuid4()}",
            debtor=debtor,
            creditor=creditor,
            currency=curr.value,
            amount=amount_str,
            charge_bearer="SLEV",
            memo=f"Interbank settlement {debtor_bank.bic} -> {creditor_bank.bic}"
        )

    def run_simulation(self, total_transfers: int = 1000) -> Dict[str, Any]:
        print(f"Starting Bank Network Simulation ({total_transfers} transfers, mock={self.use_mock})...")
        start_time = time.time()
        success = 0
        failed = 0
        total_vol = 0.0
        rail_counts: Dict[str, int] = {}

        for i in range(total_transfers):
            req = self.generate_random_transfer()
            amt = float(req.amount)

            if self.use_mock:
                res = self.mock_engine.transfer(req)
                if res.get("state") == "SETTLED":
                    success += 1
                    total_vol += amt
                    r = res.get("selected_rail", "FEDNOW")
                    rail_counts[r] = rail_counts.get(r, 0) + 1
                else:
                    failed += 1
            else:
                try:
                    resp = self.client.execute_transfer(req)
                    success += 1
                    total_vol += amt
                    r = resp.selected_rail
                    rail_counts[r] = rail_counts.get(r, 0) + 1
                except (CofferApiError, Exception):
                    failed += 1

            if (i + 1) % (total_transfers // 5 or 1) == 0:
                elapsed = time.time() - start_time
                rate = (i + 1) / elapsed if elapsed > 0 else 0
                print(f"  Processed {i + 1}/{total_transfers} transfers (rate: {rate:.1f} tx/s)")

        elapsed = time.time() - start_time
        rate = total_transfers / elapsed if elapsed > 0 else 0

        print("\n================================================================================")
        print(" COFFER MULTI-BANK CLEARING NETWORK SIMULATION SUMMARY")
        print("================================================================================")
        print(f" Total Ingress Transfers : {total_transfers}")
        print(f" Successfully Cleared    : {success} ({success / total_transfers * 100:.1f}%)")
        print(f" Failed / Quarantined    : {failed}")
        print(f" Total Gross Volume      : ${total_vol:,.2f}")
        print(f" Execution Wall Time     : {elapsed:.3f} seconds")
        print(f" Effective Ingress Rate  : {rate:.1f} transfers/second")
        print(" Rail Settlement Breakdown:")
        for r, cnt in sorted(rail_counts.items()):
            print(f"   - {r:<15}: {cnt:>6} transactions ({cnt / (success or 1) * 100:>5.1f}%)")
        print("================================================================================\n")

        return {
            "total": total_transfers,
            "success": success,
            "failed": failed,
            "gross_volume": total_vol,
            "elapsed_seconds": elapsed,
            "rate_tps": rate,
            "rail_breakdown": rail_counts
        }


def main():
    parser = argparse.ArgumentParser(description="Coffer Multi-Bank Network Clearing Simulator")
    parser.add_argument("--transfers", "-n", type=int, default=1000, help="Total synthetic transfers to execute")
    parser.add_argument("--mock", action="store_true", help="Run with in-memory mock engine")
    parser.add_argument("--url", default="http://127.0.0.1:8990", help="Coffer gateway REST URL")
    args = parser.parse_args()

    client = None if args.mock else CofferClient(base_url=args.url)
    sim = BankNetworkSimulator(client=client, use_mock=args.mock)
    sim.run_simulation(total_transfers=args.transfers)


if __name__ == "__main__":
    main()
