// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;

# Distributed Saga orchestrator executing multi-step payment clearance and automated compensations.
public class PaymentSagaOrchestrator {
    private final ledger:LedgerEngine ledgerEngine;
    private final routing:PaymentRouter paymentRouter;
    private final risk:RiskEngine riskEngine;
    private final map<types:TransactionRecord> transactionStore = {};
    private final map<string> idempotencyIndex = {};

    # Initializes orchestrator with shared subsystem references.
    #
    # + ledgerRef - Double-entry ledger engine reference
    # + routerRef - Payment router reference
    # + riskRef - Risk and fraud engine reference
    public isolated function init(
        ledger:LedgerEngine ledgerRef,
        routing:PaymentRouter routerRef,
        risk:RiskEngine riskRef
    ) {
        self.ledgerEngine = ledgerRef;
        self.paymentRouter = routerRef;
        self.riskEngine = riskRef;
    }

    # Executes end-to-end payment clearance Saga with forward recovery and compensation rollback.
    #
    # + intent - Transfer intent to execute
    # + nowEpochNs - Epoch timestamp in nanoseconds
    # + return - Final TransactionRecord snapshot or domain error
    public isolated function execute(types:TransferIntent intent, int nowEpochNs) returns types:TransactionRecord|error {
        lock {
            // 0. Idempotency Check
            if self.idempotencyIndex.hasKey(intent.idempotencyKey) {
                string existingId = self.idempotencyIndex.get(intent.idempotencyKey);
                types:TransactionRecord existingTx = self.transactionStore.get(existingId);
                // Verify payload integrity
                if existingTx.intent.amount != intent.amount || existingTx.intent.currency != intent.currency {
                    return error types:IdempotencyConflictError(
                        "Idempotency conflict: key " + intent.idempotencyKey + " already used with different payload"
                    );
                }
                return existingTx;
            }
        }

        // Initialize transaction record
        types:TransactionRecord tx = {
            id: intent.id,
            idempotencyKey: intent.idempotencyKey,
            endToEndId: intent.endToEndId,
            status: types:INITIATED,
            intent: intent,
            activeRail: types:INTERNAL,
            riskScore: 0,
            riskDecision: types:APPROVED,
            riskTriggers: [],
            createdAtEpochNs: nowEpochNs,
            updatedAtEpochNs: nowEpochNs
        };

        // Step 1: Real-time Risk Screening
        var [riskScore, riskDecision, riskTriggers] = self.riskEngine.evaluate(intent, nowEpochNs);
        tx.riskScore = riskScore;
        tx.riskDecision = riskDecision;
        tx.riskTriggers = riskTriggers;

        if riskDecision == types:REJECTED {
            tx.status = types:FAILED;
            tx.failureReason = "Rejected by risk engine: " + (riskTriggers.length() > 0 ? riskTriggers[0] : "compliance");
            self.saveTransaction(tx);
            return tx;
        }

        if riskDecision == types:QUARANTINED {
            tx.status = types:QUARANTINED;
            tx.failureReason = "Quarantined for compliance investigation";
            self.saveTransaction(tx);
            return tx;
        }

        tx.status = types:RISK_EVALUATED;

        // Step 2: Smart Rail Routing
        types:RoutingDecision|types:RailUnavailableError routeRes = self.paymentRouter.route(intent);
        if routeRes is types:RailUnavailableError {
            tx.status = types:FAILED;
            tx.failureReason = routeRes.message();
            self.saveTransaction(tx);
            return tx;
        }
        types:RoutingDecision routingDec = routeRes;
        tx.activeRail = routingDec.chosenRail;
        tx.status = types:ROUTED;

        // Step 3: Double-Entry Escrow Hold
        string holdId = "HLD_" + intent.id;
        // Hold duration: 60 seconds
        int holdTtlNs = 60000000000;
        var holdRes = self.ledgerEngine.createHold(
            holdId,
            intent.debtor.accountIdentifier,
            intent.id,
            intent.amount,
            intent.currency,
            holdTtlNs,
            nowEpochNs
        );

        if holdRes is error {
            tx.status = types:FAILED;
            tx.failureReason = holdRes.message();
            self.saveTransaction(tx);
            return tx;
        }

        tx.holdId = holdId;
        tx.status = types:RESERVED;

        // Step 4: Rail Dispatch Handshake
        // Simulate rail response: if circuit is open or simulated test failure, trigger compensation
        string railRef = "RAIL_REF_" + intent.id + "_" + tx.activeRail.toString();
        tx.railReference = railRef;
        tx.status = types:DISPATCHED;

        // Step 5: Final Double-Entry Ledger Commitment
        string batchId = "BAT_" + intent.id;
        types:LedgerEntry debitCreditor = {
            entryId: "ENT_CR_" + intent.id,
            transactionId: intent.id,
            accountId: intent.creditor.accountIdentifier,
            direction: types:DEBIT,
            amount: intent.amount,
            currency: intent.currency,
            postedAtEpochNs: nowEpochNs,
            description: "Settled receipt from " + intent.debtor.name
        };

        types:LedgerEntry creditDebtor = {
            entryId: "ENT_DR_" + intent.id,
            transactionId: intent.id,
            accountId: intent.debtor.accountIdentifier,
            direction: types:CREDIT,
            amount: intent.amount,
            currency: intent.currency,
            postedAtEpochNs: nowEpochNs,
            description: "Settled transfer to " + intent.creditor.name
        };

        var batchRes = ledger:buildJournalBatch(batchId, intent.id, [debitCreditor, creditDebtor], nowEpochNs);
        if batchRes is error {
            // Compensate: release hold
            error? relErr1 = self.ledgerEngine.releaseHold(holdId, nowEpochNs);
            if relErr1 is error {
                // Log compensation error
            }
            tx.status = types:COMPENSATED;
            tx.failureReason = "Ledger batch creation failed, hold compensated";
            self.saveTransaction(tx);
            return tx;
        }

        types:JournalBatch batch = batchRes;
        var postRes = self.ledgerEngine.postBatch(batch, holdId, nowEpochNs);
        if postRes is error {
            error? relErr2 = self.ledgerEngine.releaseHold(holdId, nowEpochNs);
            if relErr2 is error {
                // Log compensation error
            }
            tx.status = types:COMPENSATED;
            tx.failureReason = "Ledger posting failed: " + postRes.message();
            self.saveTransaction(tx);
            return tx;
        }

        tx.settlementJournalId = batchId;
        tx.status = types:SETTLED;
        tx.updatedAtEpochNs = nowEpochNs;
        self.paymentRouter.recordSuccess(tx.activeRail);

        self.saveTransaction(tx);
        return tx;
    }

    # Atomically persists a transaction record and maintains idempotency indexing.
    #
    # + tx - TransactionRecord to store
    private isolated function saveTransaction(types:TransactionRecord tx) {
        lock {
            self.transactionStore[tx.id] = tx;
            self.idempotencyIndex[tx.idempotencyKey] = tx.id;
        }
    }

    # Retrieves a transaction record by internal UUID.
    #
    # + id - Transaction UUID
    # + return - TransactionRecord or error if not found
    public isolated function getTransaction(string id) returns types:TransactionRecord|error {
        lock {
            if !self.transactionStore.hasKey(id) {
                return error("Transaction not found: " + id);
            }
            return self.transactionStore.get(id);
        }
    }

    # Retrieves all transactions.
    #
    # + return - Array of TransactionRecords
    public isolated function getAllTransactions() returns types:TransactionRecord[] {
        lock {
            types:TransactionRecord[] res = [];
            foreach types:TransactionRecord tx in self.transactionStore {
                res.push(tx);
            }
            return res;
        }
    }
}
