// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;

@test:Config {}
function testSagaEndToEndSettlement() returns error? {
    ledger:LedgerEngine lEngine = new ();
    routing:PaymentRouter pRouter = new ();
    risk:RiskEngine rEngine = new ();
    PaymentSagaOrchestrator saga = createSagaOrchestrator(lEngine, pRouter, rEngine);

    // Setup accounts
    types:Account alice = check ledger:createAccount(
        "acc_alice",
        "CHK_ALICE",
        "Alice Smith",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "2000.00",
        1730550000000000
    );
    types:Account bob = check ledger:createAccount(
        "acc_bob",
        "CHK_BOB",
        "Bob Jones",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "500.00",
        1730550000000000
    );
    check lEngine.registerAccount(alice);
    check lEngine.registerAccount(bob);

    types:FinancialInstitution chase = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:Party debtor = { id: "p1", name: "Alice", accountIdentifier: "acc_alice", institution: chase };
    types:Party creditor = { id: "p2", name: "Bob", accountIdentifier: "acc_bob", institution: chase };

    types:TransferIntent intent = {
        id: "tx_saga_001",
        idempotencyKey: "idem_saga_001",
        endToEndId: "E2E_SAGA_001",
        debtor: debtor,
        creditor: creditor,
        amount: "350.00",
        currency: types:USD,
        remittanceInformation: "Invoice settlement",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:TransactionRecord tx = check saga.execute(intent, 1730550001000000);
    test:assertEquals(tx.status, types:SETTLED);
    test:assertTrue(isSettled(tx));

    types:Account aliceAfter = check lEngine.getAccount("acc_alice");
    types:Account bobAfter = check lEngine.getAccount("acc_bob");

    test:assertEquals(aliceAfter.settledBalance, "1650.00");
    test:assertEquals(aliceAfter.availableBalance, "1650.00");
    test:assertEquals(bobAfter.settledBalance, "850.00");
    test:assertEquals(bobAfter.availableBalance, "850.00");

    // Test Idempotency: re-submit exact same intent
    types:TransactionRecord reTx = check saga.execute(intent, 1730550002000000);
    test:assertEquals(reTx.id, tx.id);
    test:assertEquals(reTx.status, types:SETTLED);
}

@test:Config {}
function testSagaIdempotencyConflict() returns error? {
    ledger:LedgerEngine lEngine = new ();
    routing:PaymentRouter pRouter = new ();
    risk:RiskEngine rEngine = new ();
    PaymentSagaOrchestrator saga = createSagaOrchestrator(lEngine, pRouter, rEngine);

    types:Account acc = check ledger:createAccount("a1", "CHK1", "Alice", types:ASSET, types:CUSTOMER_CHECKING, types:USD, "1000.00", 0);
    check lEngine.registerAccount(acc);

    types:FinancialInstitution bank = { bic: "CHASUS33XXX", routingNumber: "021000021", name: "Chase", countryCode: "US" };
    types:Party p = { id: "p1", name: "Alice", accountIdentifier: "a1", institution: bank };

    types:TransferIntent intent1 = {
        id: "tx_1",
        idempotencyKey: "idem_shared_key",
        endToEndId: "E2E_1",
        debtor: p,
        creditor: p,
        amount: "100.00",
        currency: types:USD,
        remittanceInformation: "Pmt 1",
        createdAtEpochNs: 0,
        deadlineEpochNs: 60000000000
    };
    _ = check saga.execute(intent1, 0);

    // Conflict: same idempotency key with amount 200.00
    types:TransferIntent intent2 = {
        id: "tx_2",
        idempotencyKey: "idem_shared_key",
        endToEndId: "E2E_2",
        debtor: p,
        creditor: p,
        amount: "200.00",
        currency: types:USD,
        remittanceInformation: "Pmt 2",
        createdAtEpochNs: 100,
        deadlineEpochNs: 60000000100
    };

    var conflictRes = saga.execute(intent2, 100);
    test:assertTrue(conflictRes is types:IdempotencyConflictError);
}

@test:Config {}
function testSagaInsufficientFunds() returns error? {
    ledger:LedgerEngine lEngine = new ();
    routing:PaymentRouter pRouter = new ();
    risk:RiskEngine rEngine = new ();
    PaymentSagaOrchestrator saga = createSagaOrchestrator(lEngine, pRouter, rEngine);

    types:Account poorAlice = check ledger:createAccount(
        "acc_poor", "CHK_POOR", "Poor Alice", types:ASSET, types:CUSTOMER_CHECKING, types:USD, "50.00", 0
    );
    check lEngine.registerAccount(poorAlice);

    types:FinancialInstitution bank = { bic: "CHASUS33XXX", routingNumber: "021000021", name: "Chase", countryCode: "US" };
    types:Party p = { id: "p1", name: "Alice", accountIdentifier: "acc_poor", institution: bank };

    types:TransferIntent intent = {
        id: "tx_overdraft",
        idempotencyKey: "idem_overdraft",
        endToEndId: "E2E_OVERDRAFT",
        debtor: p,
        creditor: p,
        amount: "500.00", // Exceeds 50.00 available
        currency: types:USD,
        remittanceInformation: "Overdraft attempt",
        createdAtEpochNs: 0,
        deadlineEpochNs: 60000000000
    };

    types:TransactionRecord tx = check saga.execute(intent, 0);
    test:assertEquals(tx.status, types:FAILED);
    test:assertTrue(tx.failureReason is string);
}
