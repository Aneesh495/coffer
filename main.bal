// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/io;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;

# Main entrypoint for Coffer financial settlement platform daemon.
#
# + return - Optional error
public function main() returns error? {
    io:println("============================================================");
    io:println("  COFFER: DISTRIBUTED MULTI-RAIL PAYMENT CLEARING FABRIC    ");
    io:println("  High-Assurance Double-Entry & Liquidity Settlement Engine ");
    io:println("============================================================");

    // Bootstrap initial bank settlement and customer test accounts
    types:Account chaseNostro = check ledger:createAccount(
        "acc_chase_nostro",
        "NOSTRO_CHASUS33",
        "JPMorgan Chase Settlement Clearing Nostro",
        types:ASSET,
        types:SETTLEMENT_CLEARING,
        types:USD,
        "50000000.00",
        1730550000000000
    );

    types:Account bofaNostro = check ledger:createAccount(
        "acc_bofa_nostro",
        "NOSTRO_BOFAUS3N",
        "Bank of America Settlement Clearing Nostro",
        types:ASSET,
        types:SETTLEMENT_CLEARING,
        types:USD,
        "50000000.00",
        1730550000000000
    );

    types:Account aliceChecking = check ledger:createAccount(
        "acc_alice_01",
        "CHK_ALICE_987",
        "Alice Smith Primary Checking",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "25000.00",
        1730550000000000
    );

    types:Account bobChecking = check ledger:createAccount(
        "acc_bob_02",
        "CHK_BOB_123",
        "Bob Jones Commercial Treasury",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "10000.00",
        1730550000000000
    );

    check globalState.ledgerEngine.registerAccount(chaseNostro);
    check globalState.ledgerEngine.registerAccount(bofaNostro);
    check globalState.ledgerEngine.registerAccount(aliceChecking);
    check globalState.ledgerEngine.registerAccount(bobChecking);

    // Bootstrap participant collateral for netting
    globalState.nettingEngine.getCollateralManager().setCollateral(
        "CHASUS33XXX", "100000000.00", "50000000.00", types:USD, 1730550000000000
    );
    globalState.nettingEngine.getCollateralManager().setCollateral(
        "BOFAUS3NXXX", "100000000.00", "50000000.00", types:USD, 1730550000000000
    );
    globalState.nettingEngine.getCollateralManager().setCollateral(
        "CITIUS33XXX", "100000000.00", "50000000.00", types:USD, 1730550000000000
    );

    io:println("[BOOTSTRAP] Default settlement accounts and collateral pools registered.");
    io:println("[GATEWAY] Coffer HTTP REST listening on http://127.0.0.1:8990/api/v1");
    io:println("[METRICS] OpenMetrics telemetry available at http://127.0.0.1:8990/api/v1/metrics");
    io:println("[HEALTH] Health probe available at http://127.0.0.1:8990/api/v1/health");
}
