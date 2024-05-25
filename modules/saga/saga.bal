// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;

# Factory function creating an initialized PaymentSagaOrchestrator.
#
# + ledgerRef - Double-entry ledger engine reference
# + routerRef - Payment router reference
# + riskRef - Risk and fraud engine reference
# + return - Initialized orchestrator instance
public isolated function createSagaOrchestrator(
    ledger:LedgerEngine ledgerRef,
    routing:PaymentRouter routerRef,
    risk:RiskEngine riskRef
) returns PaymentSagaOrchestrator {
    return new PaymentSagaOrchestrator(ledgerRef, routerRef, riskRef);
}

# Verifies whether a transaction has completed terminal settlement.
#
# + tx - TransactionRecord to inspect
# + return - True if settled successfully
public isolated function isSettled(types:TransactionRecord tx) returns boolean {
    return tx.status == types:SETTLED;
}
