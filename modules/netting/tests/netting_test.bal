// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;

@test:Config {}
function testMultilateralNettingThreeBankCycle() returns error? {
    NettingEngine engine = new ();
    CollateralManager cMgr = engine.getCollateralManager();

    // Post ample collateral for Chase, BofA, and Citi
    cMgr.setCollateral("CHASUS33XXX", "50000000.00", "50000000.00", types:USD, 1730550000000000);
    cMgr.setCollateral("BOFAUS3NXXX", "50000000.00", "50000000.00", types:USD, 1730550000000000);
    cMgr.setCollateral("CITIUS33XXX", "50000000.00", "50000000.00", types:USD, 1730550000000000);

    // Chase owes BofA $100
    engine.accumulateDebt({
        debtorBic: "CHASUS33XXX",
        creditorBic: "BOFAUS3NXXX",
        amount: "100.00",
        currency: types:USD
    });

    // BofA owes Citi $80
    engine.accumulateDebt({
        debtorBic: "BOFAUS3NXXX",
        creditorBic: "CITIUS33XXX",
        amount: "80.00",
        currency: types:USD
    });

    // Citi owes Chase $70
    engine.accumulateDebt({
        debtorBic: "CITIUS33XXX",
        creditorBic: "CHASUS33XXX",
        amount: "70.00",
        currency: types:USD
    });

    NettingCycleResult res = check engine.executeCycle("CYC_2026_01", types:USD);

    test:assertEquals(res.cycleId, "CYC_2026_01");
    test:assertEquals(res.totalGrossVolume, "250.00");
    test:assertEquals(res.totalNetVolume, "30.00");
    test:assertTrue(res.balanced);
    // Gross $250 netted down to $30: 88% liquidity savings
    test:assertTrue(res.liquidityEfficiencyRatio >= 85.0d);
}

@test:Config {}
function testNettingCollateralDeficitDetection() returns error? {
    NettingEngine engine = new ();
    CollateralManager cMgr = engine.getCollateralManager();

    // Post very small collateral for Chase ($10)
    cMgr.setCollateral("CHASUS33XXX", "10.00", "0.00", types:USD, 1730550000000000);
    cMgr.setCollateral("BOFAUS3NXXX", "1000.00", "0.00", types:USD, 1730550000000000);

    // Chase owes BofA $500, but only has $10 collateral
    engine.accumulateDebt({
        debtorBic: "CHASUS33XXX",
        creditorBic: "BOFAUS3NXXX",
        amount: "500.00",
        currency: types:USD
    });

    var res = engine.executeCycle("CYC_DEFICIT", types:USD);
    test:assertTrue(res is types:NettingDeficitError);
}
