// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;

@test:Config {}
function testRiskCleanEvaluation() {
    RiskEngine engine = new ();

    types:FinancialInstitution inst = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:Party debtor = { id: "usr_alice", name: "Alice Good", accountIdentifier: "CHK1", institution: inst };
    types:Party creditor = { id: "usr_bob", name: "Bob Good", accountIdentifier: "CHK2", institution: inst };

    types:TransferIntent intent = {
        id: "tx_clean",
        idempotencyKey: "idem_clean",
        endToEndId: "E2E_CLEAN",
        debtor: debtor,
        creditor: creditor,
        amount: "150.00",
        currency: types:USD,
        remittanceInformation: "Dinner split",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    var [score, decision, triggers] = engine.evaluate(intent, 1730550000000000);
    test:assertEquals(score, 0);
    test:assertEquals(decision, types:APPROVED);
    test:assertEquals(triggers.length(), 0);
}

@test:Config {}
function testRiskSanctionMatchRejection() {
    RiskEngine engine = new ();

    types:FinancialInstitution inst = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:Party debtor = { id: "usr_alice", name: "Alice Good", accountIdentifier: "CHK1", institution: inst };
    types:Party evilCreditor = { id: "usr_evil", name: "Global Laundering Front LLC", accountIdentifier: "CHK2", institution: inst };

    types:TransferIntent intent = {
        id: "tx_sanction",
        idempotencyKey: "idem_sanction",
        endToEndId: "E2E_SANCTION",
        debtor: debtor,
        creditor: evilCreditor,
        amount: "5000.00",
        currency: types:USD,
        remittanceInformation: "Suspicious wire",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    var [score, decision, triggers] = engine.evaluate(intent, 1730550000000000);
    test:assertEquals(score, 100);
    test:assertEquals(decision, types:REJECTED);
    test:assertTrue(triggers.length() > 0);
    test:assertTrue(triggers[0].includes("SANCTION_MATCH"));
}

@test:Config {}
function testRiskStructuringAndQuarantine() returns error? {
    RiskEngine engine = new ();

    types:FinancialInstitution inst = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:Party debtor = { id: "usr_smurf", name: "Suspicious Sender", accountIdentifier: "CHK1", institution: inst };
    types:Party creditor = { id: "usr_dest", name: "Beneficiary", accountIdentifier: "CHK2", institution: inst };

    // Send first $9,950 payment
    types:TransferIntent tx1 = {
        id: "tx_smurf_1",
        idempotencyKey: "idem_s1",
        endToEndId: "E2E_S1",
        debtor: debtor,
        creditor: creditor,
        amount: "9950.00",
        currency: types:USD,
        remittanceInformation: "Leg 1",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };
    _ = engine.evaluate(tx1, 1730550000000000);

    // Send second $9,950 payment 10 seconds later: triggers STRUCTURING_DETECTED
    types:TransferIntent tx2 = {
        id: "tx_smurf_2",
        idempotencyKey: "idem_s2",
        endToEndId: "E2E_S2",
        debtor: debtor,
        creditor: creditor,
        amount: "9950.00",
        currency: types:USD,
        remittanceInformation: "Leg 2",
        createdAtEpochNs: 1730550010000000,
        deadlineEpochNs: 1730550070000000
    };
    var [score2, decision2, triggers2] = engine.evaluate(tx2, 1730550010000000);
    test:assertTrue(score2 >= 45);
    test:assertNotEquals(decision2, types:APPROVED);

    // Verify quarantine workflow
    QuarantineStore qStore = engine.getQuarantineStore();
    qStore.add({
        transactionId: "tx_smurf_2",
        intent: tx2,
        riskScore: score2,
        triggers: triggers2,
        quarantinedAtEpochNs: 1730550010000000,
        status: "PENDING_REVIEW"
    });

    QuarantinedItem released = check qStore.release("tx_smurf_2");
    test:assertEquals(released.status, "RELEASED");
}
