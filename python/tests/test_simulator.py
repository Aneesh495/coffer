"""
Unit test suite for bank network simulation and liquidity stress algorithms.
"""

import unittest
from simulator.bank_network_sim import BankNetworkSimulator, LocalMockEngine
from simulator.liquidity_stress_sim import LiquidityStressSimulator
from coffer_sdk.models import NettingObligation


class TestSimulatorEngines(unittest.TestCase):

    def test_local_mock_engine_transfer(self):
        engine = LocalMockEngine()
        sim = BankNetworkSimulator(use_mock=True)
        req = sim.generate_random_transfer()
        res = engine.transfer(req)

        self.assertEqual(res["state"], "SETTLED")
        self.assertIn("PMT-", res["payment_id"])
        self.assertGreater(engine.cleared_count, 0)
        self.assertGreater(engine.total_volume, 0.0)

    def test_bank_network_simulation_batch(self):
        sim = BankNetworkSimulator(use_mock=True)
        res = sim.run_simulation(total_transfers=50)

        self.assertEqual(res["total"], 50)
        self.assertEqual(res["success"], 50)
        self.assertEqual(res["failed"], 0)
        self.assertGreater(res["gross_volume"], 0.0)
        self.assertGreater(res["rate_tps"], 0.0)

    def test_liquidity_stress_netting_zero_sum(self):
        sim = LiquidityStressSimulator()
        obligations = [
            NettingObligation(obligation_id="O1", debtor_bic="CHASUS33XXX", creditor_bic="BOFAUS3NXXX", currency="USD", amount="500000.00"),
            NettingObligation(obligation_id="O2", debtor_bic="BOFAUS3NXXX", creditor_bic="CITIUS33XXX", currency="USD", amount="400000.00"),
            NettingObligation(obligation_id="O3", debtor_bic="CITIUS33XXX", creditor_bic="CHASUS33XXX", currency="USD", amount="450000.00"),
        ]
        result = sim.run_netting_cycle(obligations)

        self.assertEqual(result["total_obligations"], 3)
        self.assertEqual(result["gross_volume"], 1350000.00)
        self.assertTrue(result["is_balanced"])
        # Chase owes 500k, receives 450k -> net -50k
        # BofA owes 400k, receives 500k -> net +100k
        # Citi owes 450k, receives 400k -> net -50k
        positions = result["net_positions"]
        self.assertAlmostEqual(positions["CHASUS33XXX"], -50000.00, places=2)
        self.assertAlmostEqual(positions["BOFAUS3NXXX"], 100000.00, places=2)
        self.assertAlmostEqual(positions["CITIUS33XXX"], -50000.00, places=2)
        self.assertAlmostEqual(sum(positions.values()), 0.00, places=2)


if __name__ == "__main__":
    unittest.main()
