// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.netting;

# Integration test verifying a 4-participant multilateral netting session.
#
# + return - Optional error on assertion failure
@test:Config {}
function testIntegrationMultilateralNettingFourParticipants() returns error? {
    netting:CollateralManager collateralMgr = new ();
    int nowNs = 1730550000000000;

    collateralMgr.setCollateral("CHASUS33XXX", "10000000.00", "2000000.00", types:USD, nowNs);
    collateralMgr.setCollateral("BOFAUS3NXXX", "10000000.00", "2000000.00", types:USD, nowNs);
    collateralMgr.setCollateral("CITIUS33XXX", "10000000.00", "2000000.00", types:USD, nowNs);
    collateralMgr.setCollateral("WFBIUS6SXXX", "10000000.00", "2000000.00", types:USD, nowNs);

    types:BilateralDebt[] debts = [
        { debtorBic: "CHASUS33XXX", creditorBic: "BOFAUS3NXXX", amount: "3000000.00", currency: types:USD },
        { debtorBic: "BOFAUS3NXXX", creditorBic: "CITIUS33XXX", amount: "2500000.00", currency: types:USD },
        { debtorBic: "CITIUS33XXX", creditorBic: "WFBIUS6SXXX", amount: "2000000.00", currency: types:USD },
        { debtorBic: "WFBIUS6SXXX", creditorBic: "CHASUS33XXX", amount: "1500000.00", currency: types:USD },
        { debtorBic: "CHASUS33XXX", creditorBic: "CITIUS33XXX", amount: "1000000.00", currency: types:USD },
        { debtorBic: "BOFAUS3NXXX", creditorBic: "WFBIUS6SXXX", amount: "500000.00", currency: types:USD }
    ];

    netting:NettingCycleResult result = check netting:optimizeMultilateralCycle(
        "CYCLE-INTEG-004",
        debts,
        types:USD,
        collateralMgr
    );

    test:assertTrue(result.balanced, "Netting cycle must satisfy zero-sum invariant");
    test:assertEquals(result.status, types:NETTING_OPTIMIZED);
    test:assertEquals(result.totalGrossVolume, "10500000.00");
    test:assertTrue(result.liquidityEfficiencyRatio > 50.0d, "Netting efficiency must exceed 50 percent");
}
