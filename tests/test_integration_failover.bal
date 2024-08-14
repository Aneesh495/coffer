// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.routing;

# Integration test verifying circuit breaker trip and dynamic failover to backup rails.
#
# + return - Optional error on assertion failure
@test:Config {}
function testIntegrationCircuitBreakerAndFailover() returns error? {
    routing:PaymentRouter router = new ();

    types:FinancialInstitution bankA = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };
    types:FinancialInstitution bankB = {
        bic: "BOFAUS3NXXX",
        routingNumber: "026009593",
        name: "Bank of America",
        countryCode: "US"
    };

    types:TransferIntent intent = {
        id: "tx_failover_001",
        idempotencyKey: "idem_failover_001",
        endToEndId: "E2E_FAILOVER_1",
        debtor: { id: "p1", name: "Alice", accountIdentifier: "ACT_A", institution: bankA },
        creditor: { id: "p2", name: "Bob", accountIdentifier: "ACT_B", institution: bankB },
        amount: "5000.00",
        currency: types:USD,
        remittanceInformation: "Priority instant settlement",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    // Initial route selects primary instant rail (FedNow or RTP)
    types:RoutingDecision initialDecision = check router.route(intent);
    types:PaymentRail primaryRail = initialDecision.chosenRail;

    // Simulate 5 consecutive connection timeouts on primary rail to trip circuit breaker
    int idx = 0;
    while idx < 5 {
        router.recordFailure(primaryRail, 1730550000000);
        idx = idx + 1;
    }

    // Verify circuit is now tripped open
    types:RailHealth health = check router.getRailHealth(primaryRail);
    test:assertTrue(health.circuitOpen, "Circuit breaker must be tripped open after threshold errors");

    // Route again with primary rail tripped
    types:RoutingDecision failoverDecision = check router.route(intent);
    test:assertNotEquals(failoverDecision.chosenRail, primaryRail, "Router must failover to alternate rail");
    test:assertTrue(failoverDecision.chosenRail == types:RTP || failoverDecision.chosenRail == types:ACH);
}
