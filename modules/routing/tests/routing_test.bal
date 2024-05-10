// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;

@test:Config {}
function testRoutingIntraInstitutionInternal() returns error? {
    PaymentRouter router = new ();

    types:FinancialInstitution chase = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase Bank, N.A.",
        countryCode: "US"
    };

    types:Party debtor = {
        id: "usr_alice",
        name: "Alice",
        accountIdentifier: "CHK_01",
        institution: chase
    };

    types:Party creditor = {
        id: "usr_bob",
        name: "Bob",
        accountIdentifier: "CHK_02",
        institution: chase
    };

    types:TransferIntent intent = {
        id: "tx_intra",
        idempotencyKey: "idem_intra",
        endToEndId: "E2E_INTRA",
        debtor: debtor,
        creditor: creditor,
        amount: "500.00",
        currency: types:USD,
        remittanceInformation: "Book transfer",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:RoutingDecision dec = check router.route(intent);
    test:assertEquals(dec.chosenRail, types:INTERNAL);
    test:assertEquals(dec.estimatedFeeCents, 0);
    test:assertEquals(dec.estimatedLatencyMs, 5);
}

@test:Config {}
function testRoutingCircuitBreakerFailover() returns error? {
    PaymentRouter router = new ();

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

    types:Party debtor = { id: "p1", name: "Alice", accountIdentifier: "CHK1", institution: chase };
    types:Party creditor = { id: "p2", name: "Bob", accountIdentifier: "CHK2", institution: bofa };

    types:TransferIntent intent = {
        id: "tx_cross",
        idempotencyKey: "idem_cross",
        endToEndId: "E2E_CROSS",
        debtor: debtor,
        creditor: creditor,
        amount: "1000.00",
        currency: types:USD,
        remittanceInformation: "Interbank payment",
        preferredRail: types:FEDNOW,
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    // Initially FEDNOW is healthy
    types:RoutingDecision dec1 = check router.route(intent);
    test:assertEquals(dec1.chosenRail, types:FEDNOW);

    // Simulate 5 consecutive errors on FEDNOW to trip circuit breaker
    int idx = 0;
    while idx < 5 {
        router.recordFailure(types:FEDNOW, 1730550001000);
        idx = idx + 1;
    }

    types:RailHealth fedHealth = check router.getRailHealth(types:FEDNOW);
    test:assertTrue(fedHealth.circuitOpen);

    // Next route should failover from FEDNOW to RTP or ACH
    types:RoutingDecision dec2 = check router.route(intent);
    test:assertNotEquals(dec2.chosenRail, types:FEDNOW);
    test:assertTrue(dec2.chosenRail == types:RTP || dec2.chosenRail == types:ACH);
}

@test:Config {}
function testRoutingSepaInstantForEur() returns error? {
    PaymentRouter router = new ();

    types:FinancialInstitution bnp = {
        bic: "BNPAFR2XXXX",
        routingNumber: "3000400001",
        name: "BNP Paribas",
        countryCode: "FR"
    };
    types:FinancialInstitution db = {
        bic: "DEUTDEDDXXX",
        routingNumber: "50070010",
        name: "Deutsche Bank AG",
        countryCode: "DE"
    };

    types:Party debtor = { id: "p1", name: "Jean", accountIdentifier: "FR763000400001", institution: bnp };
    types:Party creditor = { id: "p2", name: "Hans", accountIdentifier: "DE8950070010", institution: db };

    types:TransferIntent intent = {
        id: "tx_eur",
        idempotencyKey: "idem_eur",
        endToEndId: "E2E_EUR",
        debtor: debtor,
        creditor: creditor,
        amount: "2500.00",
        currency: types:EUR,
        remittanceInformation: "SEPA Cross-border",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:RoutingDecision dec = check router.route(intent);
    test:assertEquals(dec.chosenRail, types:SEPA_INSTANT);
}
