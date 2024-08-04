// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.fixedpoint;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;
import aneeshkrishna/coffer.netting;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.saga;

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

# Regression test for Bug #3: Substring containment false positive in sanctions screening.
# Prior to fix, searching for clean names like 'Alice' matched blocked entities like 'VIKTOR MALICE DRUG CARTEL'
# because 'MALICE' ends with 'ALICE'. Fixed by requiring whole-phrase or token-boundary matching.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugSanctionsSubstringFalsePositive() returns error? {
    risk:SanctionsFilter filter = new ();

    // Clean common names that would have matched substring 'ALICE' in 'VIKTOR MALICE DRUG CARTEL'
    test:assertEquals(filter.screenName("Alice Smith"), ());
    test:assertEquals(filter.screenName("Alice Cooper"), ());
    test:assertEquals(filter.screenName("Alice"), ());

    // True sanctioned match should still match
    var matchRes = filter.screenName("Viktor Malice Drug Cartel");
    test:assertTrue(matchRes is risk:SanctionEntry);
}

# Regression test for Bug #4: Net-zero participant collateral deficit check avoidance.
# Prior to fix, participants with exact net-zero balance (gross credits equal gross debits)
# could mistakenly trigger margin checks if net debit was not checked for non-zero strictly.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugNettingZeroPositionCollateral() returns error? {
    netting:CollateralManager collateralMgr = new ();
    // Bank A has zero collateral posted
    collateralMgr.setCollateral("BANKAZZZXXX", "0.00", "0.00", types:USD, 1730550000000000);
    collateralMgr.setCollateral("BANKBZZZXXX", "50000.00", "0.00", types:USD, 1730550000000000);

    // Circular offsetting debts: Bank A owes Bank B 1000, Bank B owes Bank A 1000 -> Bank A net is 0.00
    types:BilateralDebt[] debts = [
        {
            debtorBic: "BANKAZZZXXX",
            creditorBic: "BANKBZZZXXX",
            amount: "1000.00",
            currency: types:USD
        },
        {
            debtorBic: "BANKBZZZXXX",
            creditorBic: "BANKAZZZXXX",
            amount: "1000.00",
            currency: types:USD
        }
    ];

    netting:NettingCycleResult result = check netting:optimizeMultilateralCycle("cycle_reg_4", debts, types:USD, collateralMgr);
    test:assertTrue(result.balanced, "Netting cycle must remain balanced");
    test:assertEquals(result.totalNetVolume, "0.00");
}

# Regression test for Bug #5: Saga idempotency replay prevention of duplicate journal executions.
# Submitting an identical idempotency key must return the original cleared record without
# deducting debtor balance a second time or generating duplicate journal entries.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugSagaDuplicateExecutionPrevention() returns error? {
    ledger:LedgerEngine lEngine = new ();
    routing:PaymentRouter rEngine = new ();
    risk:RiskEngine rkEngine = new ();

    types:FinancialInstitution bank = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };

    types:Account debtorAcct = {
        id: "ACT_DEBTOR_IDEMP",
        accountIdentifier: "CHK-001",
        name: "Alice Checking",
        accountType: types:ASSET,
        category: types:CUSTOMER_CHECKING,
        currency: types:USD,
        status: types:ACTIVE,
        settledBalance: "10000.00",
        pendingHoldsBalance: "0.00",
        availableBalance: "10000.00",
        version: 1,
        createdAtEpochNs: 1730550000000000,
        updatedAtEpochNs: 1730550000000000
    };

    types:Account creditorAcct = {
        id: "ACT_CREDITOR_IDEMP",
        accountIdentifier: "CHK-002",
        name: "Bob Checking",
        accountType: types:LIABILITY,
        category: types:CUSTOMER_CHECKING,
        currency: types:USD,
        status: types:ACTIVE,
        settledBalance: "0.00",
        pendingHoldsBalance: "0.00",
        availableBalance: "0.00",
        version: 1,
        createdAtEpochNs: 1730550000000000,
        updatedAtEpochNs: 1730550000000000
    };

    check lEngine.registerAccount(debtorAcct);
    check lEngine.registerAccount(creditorAcct);

    saga:PaymentSagaOrchestrator orchestrator = new (lEngine, rEngine, rkEngine);

    types:TransferIntent intent = {
        id: "tx_idem_test_1",
        idempotencyKey: "unique_idem_key_999",
        endToEndId: "E2E_IDEM_1",
        debtor: { id: "p1", name: "Alice", accountIdentifier: "ACT_DEBTOR_IDEMP", institution: bank },
        creditor: { id: "p2", name: "Bob", accountIdentifier: "ACT_CREDITOR_IDEMP", institution: bank },
        amount: "500.00",
        currency: types:USD,
        remittanceInformation: "Idempotent payment test",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    // First execution
    types:TransactionRecord res1 = check orchestrator.execute(intent, 1730550001000000);
    test:assertEquals(res1.status, types:SETTLED);

    // Second execution with identical idempotency key
    types:TransactionRecord res2 = check orchestrator.execute(intent, 1730550002000000);
    test:assertEquals(res2.status, types:SETTLED);
    test:assertEquals(res2.id, res1.id);

    // Debtor balance should be 9500.00 (deducted exactly once, not twice to 9000.00)
    types:Account debtorPost = check lEngine.getAccount("ACT_DEBTOR_IDEMP");
    test:assertEquals(debtorPost.settledBalance, "9500.00");
}
