// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;

@test:Config {}
function testTypesCurrenciesAndRails() {
    Currency cur = USD;
    test:assertEquals(cur, "USD");

    PaymentRail rail = FEDNOW;
    test:assertEquals(rail, "FEDNOW");

    TransactionStatus status = INITIATED;
    test:assertEquals(status, "INITIATED");

    AccountType accType = ASSET;
    test:assertEquals(accType, "ASSET");
}

@test:Config {}
function testTypesTransferIntentRecord() {
    FinancialInstitution instA = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase Bank, N.A.",
        countryCode: "US"
    };

    Party debtor = {
        id: "usr_alice_01",
        name: "Alice Smith",
        accountIdentifier: "chk_9876543210",
        institution: instA
    };

    Party creditor = {
        id: "usr_bob_02",
        name: "Bob Jones",
        accountIdentifier: "chk_1234567890",
        institution: instA
    };

    TransferIntent intent = {
        id: "tx_1001",
        idempotencyKey: "idem_abc_123",
        endToEndId: "E2E_20261102_0001",
        debtor: debtor,
        creditor: creditor,
        amount: "1500.50",
        currency: USD,
        remittanceInformation: "Invoice 90210 payment",
        preferredRail: FEDNOW,
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    test:assertEquals(intent.id, "tx_1001");
    test:assertEquals(intent.amount, "1500.50");
    test:assertEquals(intent.debtor.name, "Alice Smith");
    test:assertEquals(intent.creditor.name, "Bob Jones");
}
