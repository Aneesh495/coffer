// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;
import aneeshkrishna/coffer.saga;

# End-to-end integration test verifying full multi-rail payment clearance workflow.
#
# + return - Optional error on assertion failure
@test:Config {}
function testIntegrationEndToEndClearingWorkflow() returns error? {
    ledger:LedgerEngine lEngine = new ();
    routing:PaymentRouter rEngine = new ();
    risk:RiskEngine rkEngine = new ();

    types:FinancialInstitution chase = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:FinancialInstitution bofa = {
        bic: "BOFAUS3NXXX",
        routingNumber: "026009593",
        name: "Bank of America",
        countryCode: "US"
    };

    types:Account debtor = {
        id: "ACT_E2E_DEBTOR",
        accountIdentifier: "CHK-1001",
        name: "Alpha Corp Treasury",
        accountType: types:ASSET,
        category: types:CUSTOMER_CHECKING,
        currency: types:USD,
        status: types:ACTIVE,
        settledBalance: "250000.00",
        pendingHoldsBalance: "0.00",
        availableBalance: "250000.00",
        version: 1,
        createdAtEpochNs: 1730550000000000,
        updatedAtEpochNs: 1730550000000000
    };

    types:Account creditor = {
        id: "ACT_E2E_CREDITOR",
        accountIdentifier: "CHK-2002",
        name: "Omega Holdings LLC",
        accountType: types:ASSET,
        category: types:CUSTOMER_CHECKING,
        currency: types:USD,
        status: types:ACTIVE,
        settledBalance: "50000.00",
        pendingHoldsBalance: "0.00",
        availableBalance: "50000.00",
        version: 1,
        createdAtEpochNs: 1730550000000000,
        updatedAtEpochNs: 1730550000000000
    };

    check lEngine.registerAccount(debtor);
    check lEngine.registerAccount(creditor);

    saga:PaymentSagaOrchestrator orchestrator = new (lEngine, rEngine, rkEngine);

    types:TransferIntent intent = {
        id: "tx_e2e_clear_001",
        idempotencyKey: "idem_e2e_001",
        endToEndId: "E2E-CHASE-BOFA-001",
        debtor: { id: "p1", name: "Alpha Corp", accountIdentifier: "ACT_E2E_DEBTOR", institution: chase },
        creditor: { id: "p2", name: "Omega Holdings", accountIdentifier: "ACT_E2E_CREDITOR", institution: bofa },
        amount: "15000.00",
        currency: types:USD,
        remittanceInformation: "Interbank invoice payment",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:TransactionRecord tx = check orchestrator.execute(intent, 1730550001000000);

    test:assertEquals(tx.status, types:SETTLED);
    test:assertEquals(tx.riskDecision, types:APPROVED);
    test:assertNotEquals(tx.settlementJournalId, ());

    // Verify debtor account balances
    types:Account debtorPost = check lEngine.getAccount("ACT_E2E_DEBTOR");
    test:assertEquals(debtorPost.settledBalance, "235000.00");
    test:assertEquals(debtorPost.availableBalance, "235000.00");

    // Verify creditor account balances
    types:Account creditorPost = check lEngine.getAccount("ACT_E2E_CREDITOR");
    test:assertEquals(creditorPost.settledBalance, "65000.00");
    test:assertEquals(creditorPost.availableBalance, "65000.00");
}
