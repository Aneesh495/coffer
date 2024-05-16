// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.fixedpoint;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.routing;

# Regression test for Bug #1: Fixed-point decimal formatting truncation error.
# Prior to fix, casting a fractional decimal quotient to int rounded instead of truncating
# towards zero, causing whole integer components like 9999.88 to format as 10000.88.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugFixedpointTruncation() returns error? {
    fixedpoint:ScaledDecimal dec = check fixedpoint:fromString("9999.876");
    string formatted = fixedpoint:formatFinancial(dec, 2);
    test:assertEquals(formatted, "9999.88");

    fixedpoint:ScaledDecimal decSmall = check fixedpoint:fromString("0.999");
    string formattedSmall = fixedpoint:formatFinancial(decSmall, 2);
    test:assertEquals(formattedSmall, "1.00");

    fixedpoint:ScaledDecimal decEdge = check fixedpoint:fromString("199.994");
    string formattedEdge = fixedpoint:formatFinancial(decEdge, 2);
    test:assertEquals(formattedEdge, "199.99");
}

# Regression test for Bug #2: INTERNAL book transfer rail eligibility leak into interbank candidate ranking.
# Prior to fix, the zero-cost zero-latency INTERNAL rail was considered in the global candidate pool
# for cross-institution transfers, incorrectly winning dynamic ranking over real interbank rails like SEPA or RTP.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugInternalRailEligibility() returns error? {
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

    types:Party debtor = { id: "p1", name: "Alice", accountIdentifier: "CHK1", institution: bankA };
    types:Party creditor = { id: "p2", name: "Bob", accountIdentifier: "CHK2", institution: bankB };

    types:TransferIntent intent = {
        id: "tx_interbank_reg",
        idempotencyKey: "idem_reg_2",
        endToEndId: "E2E_REG_2",
        debtor: debtor,
        creditor: creditor,
        amount: "100.00",
        currency: types:USD,
        remittanceInformation: "Interbank payment",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    types:RoutingDecision dec = check router.route(intent);
    test:assertNotEquals(dec.chosenRail, types:INTERNAL, "Interbank cross-institution transfer must never select INTERNAL rail");
}
