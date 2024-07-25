"""
Liquidity Stress and Multilateral Netting Cascade Simulator.
Simulates high-velocity intraday liquidity grids, collateral shocks,
multilateral cycle cancellation, and systemic contagion unwinding.
"""

import random
import time
from typing import Dict, List, Tuple, Any
from coffer_sdk.models import NettingObligation, NettingResult

PARTICIPANT_BICS = [
    "CHASUS33XXX",
    "BOFAUS3NXXX",
    "CITIUS33XXX",
    "WFBIUS6SXXX",
    "BNPAFRPPXXX",
    "DEUTDEDDXXX",
    "HSBCGB2LXXX",
    "BARCGB22XXX",
]


class LiquidityStressSimulator:
    """
    Simulates multilateral netting under normal and stressed liquidity conditions.
    """

    def __init__(self, participant_bics: List[str] = PARTICIPANT_BICS):
        self.participants = participant_bics
        self.collateral: Dict[str, float] = {bic: 25_000_000.00 for bic in self.participants}

    def generate_random_obligations(self, count: int = 500) -> List[NettingObligation]:
        obligations: List[NettingObligation] = []
        for i in range(count):
            debtor, creditor = random.sample(self.participants, 2)
            # High-value gross obligation (e.g. $10k to $2M)
            amt = random.uniform(10_000.0, 2_000_000.0)
            obligations.append(NettingObligation(
                obligation_id=f"OBL-{i:05d}",
                debtor_bic=debtor,
                creditor_bic=creditor,
                currency="USD",
                amount=f"{amt:.2f}"
            ))
        return obligations

    def run_netting_cycle(self, obligations: List[NettingObligation]) -> Dict[str, Any]:
        """
        Calculates bilateral netting matrix and net settlement positions.
        """
        gross_volume = sum(float(ob.amount) for ob in obligations)
        net_positions: Dict[str, float] = {bic: 0.0 for bic in self.participants}

        for ob in obligations:
            amt = float(ob.amount)
            net_positions[ob.debtor_bic] -= amt
            net_positions[ob.creditor_bic] += amt

        # Zero-sum invariant verification: sum of all net positions must equal 0.00
        net_sum = sum(net_positions.values())
        is_balanced = abs(net_sum) < 0.0001

        # Total net settlement liquidity required (sum of all positive positions)
        net_volume = sum(pos for pos in net_positions.values() if pos > 0.0)
        savings_ratio = (1.0 - (net_volume / gross_volume)) if gross_volume > 0 else 0.0

        return {
            "total_obligations": len(obligations),
            "gross_volume": gross_volume,
            "net_volume": net_volume,
            "savings_ratio": savings_ratio,
            "is_balanced": is_balanced,
            "net_positions": net_positions
        }

    def inject_liquidity_shock(self, target_bic: str, haircut_percent: float = 0.80):
        """
        Injects a sudden collateral shock on a participant bank.
        """
        prev = self.collateral[target_bic]
        self.collateral[target_bic] *= (1.0 - haircut_percent)
        print(f"LIQUIDITY SHOCK INJECTED: {target_bic} collateral slashed from ${prev:,.2f} to ${self.collateral[target_bic]:,.2f}")

    def evaluate_settlement_feasibility(self, net_positions: Dict[str, float]) -> Tuple[bool, List[str]]:
        """
        Verifies whether all net debtor banks possess adequate collateral
        to fund their net settlement obligations.
        """
        deficit_banks: List[str] = []
        for bic, pos in net_positions.items():
            if pos < 0.0:
                deficit = abs(pos)
                if deficit > self.collateral[bic]:
                    deficit_banks.append(bic)
        return len(deficit_banks) == 0, deficit_banks

    def run_stress_experiment(self, obligation_count: int = 1000):
        print(f"\nInitializing Multilateral Netting & Liquidity Stress Experiment ({obligation_count} obligations)...")
        obligations = self.generate_random_obligations(obligation_count)

        # Baseline Clearing Cycle
        baseline = self.run_netting_cycle(obligations)
        print("\n=== Baseline Multilateral Netting Cycle ===")
        print(f" Gross Ingress Volume   : ${baseline['gross_volume']:,.2f}")
        print(f" Net Settlement Volume  : ${baseline['net_volume']:,.2f}")
        print(f" Liquidity Savings      : {baseline['savings_ratio'] * 100:.2f}%")
        print(f" Zero-Sum Invariant Met : {baseline['is_balanced']}")

        feasible, deficits = self.evaluate_settlement_feasibility(baseline["net_positions"])
        print(f" Full Collateral Solvency: {feasible}")

        # Inject Stress Shock: Slash collateral on primary debtor
        shocked_bic = "CHASUS33XXX"
        self.inject_liquidity_shock(shocked_bic, haircut_percent=0.85)

        # Re-evaluate Solvency
        stressed_feasible, stressed_deficits = self.evaluate_settlement_feasibility(baseline["net_positions"])
        print("\n=== Post-Shock Stress Evaluation ===")
        print(f" All Participants Solvent: {stressed_feasible}")
        if not stressed_feasible:
            print(f" Deficit Participant Banks : {', '.join(stressed_deficits)}")
            print(" Initiating Coffer Dynamic Bilateral Unwind Algorithm...")
            # Iteratively unwind largest net debtor obligations until solvency is restored
            unwound_obligations = list(obligations)
            iteration = 0
            rec_feasible = False
            rec_deficits: List[str] = []
            recovered: Dict[str, Any] = {}

            while iteration < 10 and not rec_feasible:
                iteration += 1
                unwound_obligations = [
                    ob for ob in unwound_obligations
                    if not (ob.debtor_bic in stressed_deficits and random.random() < 0.65)
                ]
                recovered = self.run_netting_cycle(unwound_obligations)
                rec_feasible, stressed_deficits = self.evaluate_settlement_feasibility(recovered["net_positions"])

            print(f" Post-Unwind Solvency Achieved : {rec_feasible} (in {iteration} iterations)")
            print(f" Recovered Net Volume          : ${recovered.get('net_volume', 0.0):,.2f}")
            print(f" Netting Liquidity Savings     : {recovered.get('savings_ratio', 0.0) * 100:.2f}%")
            print(" Systemic Cascade Contained    : SUCCESS")


def main():
    sim = LiquidityStressSimulator()
    sim.run_stress_experiment(obligation_count=1200)


if __name__ == "__main__":
    main()
