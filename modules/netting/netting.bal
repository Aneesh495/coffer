// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Clearing house multilateral netting coordinator and cycle dispatcher.
public class NettingEngine {
    private final CollateralManager collateralMgr = new ();
    private types:BilateralDebt[] activeDebts = [];
    private final map<NettingCycleResult> cycleHistory = {};

    # Initializes netting engine.
    public isolated function init() {
    }

    # Adds a bilateral payment obligation into the current clearing cycle buffer.
    #
    # + debt - Bilateral debt record
    public isolated function accumulateDebt(types:BilateralDebt debt) {
        lock {
            self.activeDebts.push(debt);
        }
    }

    # Triggers optimization and multilateral netting calculation for the current window.
    #
    # + cycleId - Unique cycle UUID
    # + currency - Clearing currency
    # + return - NettingCycleResult or error
    public isolated function executeCycle(string cycleId, types:Currency currency) returns NettingCycleResult|error {
        lock {
            types:BilateralDebt[] debtsToProcess = self.activeDebts;
            NettingCycleResult res = check optimizeMultilateralCycle(cycleId, debtsToProcess, currency, self.collateralMgr);
            self.cycleHistory[cycleId] = res;
            self.activeDebts = [];
            return res;
        }
    }

    # Accesses collateral manager for participant margin management.
    #
    # + return - CollateralManager reference
    public isolated function getCollateralManager() returns CollateralManager {
        return self.collateralMgr;
    }

    # Retrieves history of settled netting cycles.
    #
    # + return - Array of NettingCycleResults
    public isolated function getCycleHistory() returns NettingCycleResult[] {
        lock {
            NettingCycleResult[] res = [];
            foreach NettingCycleResult c in self.cycleHistory {
                res.push(c);
            }
            return res;
        }
    }
}
