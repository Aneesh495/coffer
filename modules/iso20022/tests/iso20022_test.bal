// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;

@test:Config {}
function testPacs008GenerationAndValidation() returns error? {
    types:FinancialInstitution debtorBank = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase Bank, N.A.",
        countryCode: "US"
    };

    types:FinancialInstitution creditorBank = {
        bic: "BOFAUS3NXXX",
        routingNumber: "026009593",
        name: "Bank of America, N.A.",
        countryCode: "US"
    };

    types:Party debtor = {
        id: "usr_alice",
        name: "Alice Smith",
        accountIdentifier: "CHK_ALICE_01",
        institution: debtorBank
    };

    types:Party creditor = {
        id: "usr_bob",
        name: "Bob Jones",
        accountIdentifier: "CHK_BOB_02",
        institution: creditorBank
    };

    types:TransferIntent intent = {
        id: "tx_1001",
        idempotencyKey: "idem_iso_01",
        endToEndId: "E2E_20261102_001",
        debtor: debtor,
        creditor: creditor,
        amount: "5000.00",
        currency: types:USD,
        remittanceInformation: "Direct Supplier Settlement",
        preferredRail: types:FEDNOW,
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    xml pacs008Doc = check createPacs008Document(intent, "MSG_2026_001", "2026-11-02T13:30:00Z", types:FEDNOW);
    string xmlStr = pacs008Doc.toString();
    test:assertTrue(xmlStr.includes("FIToFICstmrCdtTrf"));
    test:assertTrue(xmlStr.includes("CHASUS33XXX"));
    test:assertTrue(xmlStr.includes("BOFAUS3NXXX"));
    test:assertTrue(xmlStr.includes("5000.00"));
}

@test:Config {}
function testPacs008InvalidBicValidation() {
    types:FinancialInstitution badBank = {
        bic: "INVALID", // Not 8 or 11 chars
        routingNumber: "000000000",
        name: "Bad Bank",
        countryCode: "US"
    };
    types:Party p = {
        id: "usr_bad",
        name: "Bad User",
        accountIdentifier: "ACC_01",
        institution: badBank
    };
    types:TransferIntent badIntent = {
        id: "tx_bad",
        idempotencyKey: "idem_bad",
        endToEndId: "E2E_BAD",
        debtor: p,
        creditor: p,
        amount: "100.00",
        currency: types:USD,
        remittanceInformation: "Test",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    var res = createPacs008Document(badIntent, "MSG_BAD", "2026-11-02T13:30:00Z", types:FEDNOW);
    test:assertTrue(res is types:ISOValidationError);
}

@test:Config {}
function testPacs002StatusReport() {
    types:FinancialInstitution bank = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:Party p = {
        id: "u1",
        name: "Test",
        accountIdentifier: "CHK1",
        institution: bank
    };
    types:TransferIntent intent = {
        id: "tx_2002",
        idempotencyKey: "idem_2002",
        endToEndId: "E2E_2002",
        debtor: p,
        creditor: p,
        amount: "250.00",
        currency: types:USD,
        remittanceInformation: "Test",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:TransactionRecord tx = {
        id: "tx_2002",
        idempotencyKey: "idem_2002",
        endToEndId: "E2E_2002",
        status: types:SETTLED,
        intent: intent,
        activeRail: types:FEDNOW,
        riskScore: 5,
        riskDecision: types:APPROVED,
        riskTriggers: [],
        createdAtEpochNs: 1730550000000000,
        updatedAtEpochNs: 1730550005000000
    };

    xml statusDoc = createPacs002Document(tx, "STS_MSG_001", "2026-11-02T13:30:05Z");
    string xmlStr = statusDoc.toString();
    test:assertTrue(xmlStr.includes("FIToFIPmtStsRpt"));
    test:assertTrue(xmlStr.includes("ACSC"));
}

@test:Config {}
function testCamt053Statement() {
    Camt053Statement stmt = {
        statementId: "STMT_20261102_001",
        creationDateTime: "2026-11-02T23:59:59Z",
        accountIban: "US89CHAS0210000219876543210",
        accountCurrency: types:USD,
        openingBalance: "10000.00",
        closingBalance: "15000.00",
        entries: [
            {
                entryReference: "ENT_01",
                amount: "5000.00",
                currency: types:USD,
                creditDebitIndicator: "CRDT",
                bookingDateTime: "2026-11-02T14:00:00Z",
                narrative: "FedNow Inward Settlement"
            }
        ]
    };

    xml stmtXml = serializeCamt053Xml(stmt);
    string xmlStr = stmtXml.toString();
    test:assertTrue(xmlStr.includes("BkToCstmrStmt"));
    test:assertTrue(xmlStr.includes("OPBD"));
    test:assertTrue(xmlStr.includes("CLBD"));
}
