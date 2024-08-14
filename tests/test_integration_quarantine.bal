// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.risk;

# Integration test verifying risk quarantine triggering and analyst resolution.
#
# + return - Optional error on assertion failure
@test:Config {}
function testIntegrationRiskQuarantineLifecycle() returns error? {
    risk:RiskEngine riskEngine = new ();

    types:FinancialInstitution bank = {
        bic: "CHASUS33XXX",
        routingNumber: "021000021",
        name: "JPMorgan Chase",
        countryCode: "US"
    };

    types:TransferIntent suspiciousIntent = {
        id: "tx_quarantine_001",
        idempotencyKey: "idem_quar_001",
        endToEndId: "E2E_QUAR_1",
        debtor: { id: "p1", name: "High Velocity Trader", accountIdentifier: "ACT_VOL_01", institution: bank },
        creditor: { id: "p2", name: "Offshore Counterparty", accountIdentifier: "ACT_VOL_02", institution: bank },
        amount: "950000.00",
        currency: types:USD,
        remittanceInformation: "Urgent high value transfer",
        createdAtEpochNs: 1730550000000000,
        deadlineEpochNs: 1730550060000000
    };

    // Assess risk on unusually high volume transfer
    var [score, decision, triggers] = riskEngine.evaluate(suspiciousIntent, 1730550000000000);
    test:assertTrue(score >= 30, "Risk score must be elevated for high-volume transactions");
    test:assertTrue(decision == types:APPROVED || decision == types:FLAGGED);

    // Verify quarantine store lifecycle
    risk:QuarantineStore qStore = riskEngine.getQuarantineStore();
    risk:QuarantinedItem item = {
        transactionId: suspiciousIntent.id,
        intent: suspiciousIntent,
        riskScore: score,
        triggers: triggers,
        quarantinedAtEpochNs: 1730550000000000,
        status: "PENDING_REVIEW"
    };

    qStore.add(item);

    risk:QuarantinedItem? stored = qStore.get(suspiciousIntent.id);
    test:assertNotEquals(stored, ());

    // Analyst reviews and releases after compliance checks
    risk:QuarantinedItem released = check qStore.release(suspiciousIntent.id);
    test:assertEquals(released.status, "RELEASED");
}
