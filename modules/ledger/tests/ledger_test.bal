// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;

@test:Config {}
function testLedgerAccountCreationAndHolds() returns error? {
    LedgerEngine engine = new ();

    types:Account alice = check createAccount(
        "acc_alice",
        "CHK-ALICE-001",
        "Alice Checking",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "1000.00",
        1730550000000000
    );
    check engine.registerAccount(alice);

    types:Account fetched = check engine.getAccount("acc_alice");
    test:assertEquals(fetched.settledBalance, "1000.00");
    test:assertEquals(fetched.availableBalance, "1000.00");
    test:assertEquals(fetched.pendingHoldsBalance, "0.00");

    // Place an escrow hold of 300.00
    types:AccountHold hold = check engine.createHold(
        "hld_01",
        "acc_alice",
        "tx_101",
        "300.00",
        types:USD,
        60000000000,
        1730550001000000
    );
    test:assertTrue(hold.active);

    types:Account afterHold = check engine.getAccount("acc_alice");
    test:assertEquals(afterHold.settledBalance, "1000.00");
    test:assertEquals(afterHold.availableBalance, "700.00");
    test:assertEquals(afterHold.pendingHoldsBalance, "300.00");

    // Release hold
    check engine.releaseHold("hld_01", 1730550002000000);

    types:Account afterRelease = check engine.getAccount("acc_alice");
    test:assertEquals(afterRelease.settledBalance, "1000.00");
    test:assertEquals(afterRelease.availableBalance, "1000.00");
    test:assertEquals(afterRelease.pendingHoldsBalance, "0.00");
}

@test:Config {}
function testLedgerDoubleEntryBalancedBatch() returns error? {
    LedgerEngine engine = new ();

    types:Account alice = check createAccount(
        "acc_alice",
        "CHK-ALICE-001",
        "Alice Checking",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "500.00",
        1730550000000000
    );
    types:Account bob = check createAccount(
        "acc_bob",
        "CHK-BOB-002",
        "Bob Checking",
        types:ASSET,
        types:CUSTOMER_CHECKING,
        types:USD,
        "200.00",
        1730550000000000
    );
    check engine.registerAccount(alice);
    check engine.registerAccount(bob);

    // Alice transfers 150.00 to Bob
    // Credit Alice (decreases Asset), Debit Bob (increases Asset)
    types:LedgerEntry entryAlice = {
        entryId: "ent_01",
        transactionId: "tx_transfer_01",
        accountId: "acc_alice",
        direction: types:CREDIT,
        amount: "150.00",
        currency: types:USD,
        postedAtEpochNs: 1730550005000000,
        description: "Payment to Bob"
    };

    types:LedgerEntry entryBob = {
        entryId: "ent_02",
        transactionId: "tx_transfer_01",
        accountId: "acc_bob",
        direction: types:DEBIT,
        amount: "150.00",
        currency: types:USD,
        postedAtEpochNs: 1730550005000000,
        description: "Payment from Alice"
    };

    types:JournalBatch batch = check buildJournalBatch(
        "bat_001",
        "tx_transfer_01",
        [entryAlice, entryBob],
        1730550005000000
    );
    test:assertTrue(batch.balanced);
    test:assertTrue(batch.merkleRoot.length() > 0);

    check engine.postBatch(batch, (), 1730550005000000);

    types:Account aliceAfter = check engine.getAccount("acc_alice");
    types:Account bobAfter = check engine.getAccount("acc_bob");

    test:assertEquals(aliceAfter.settledBalance, "350.00");
    test:assertEquals(aliceAfter.availableBalance, "350.00");
    test:assertEquals(bobAfter.settledBalance, "350.00");
    test:assertEquals(bobAfter.availableBalance, "350.00");
}

@test:Config {}
function testLedgerUnbalancedBatchRejection() returns error? {
    types:LedgerEntry entry1 = {
        entryId: "ent_01",
        transactionId: "tx_bad",
        accountId: "acc_1",
        direction: types:DEBIT,
        amount: "100.00",
        currency: types:USD,
        postedAtEpochNs: 1730550000000000,
        description: "Leg 1"
    };
    types:LedgerEntry entry2 = {
        entryId: "ent_02",
        transactionId: "tx_bad",
        accountId: "acc_2",
        direction: types:CREDIT,
        amount: "90.00",
        currency: types:USD,
        postedAtEpochNs: 1730550000000000,
        description: "Leg 2 unbalanced"
    };

    var res = buildJournalBatch("bat_bad", "tx_bad", [entry1, entry2], 1730550000000000);
    test:assertTrue(res is types:LedgerInvariantError);
}
