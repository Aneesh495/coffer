// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/http;
import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.ledger;
import aneeshkrishna/coffer.routing;
import aneeshkrishna/coffer.risk;
import aneeshkrishna/coffer.saga;
import aneeshkrishna/coffer.netting;
import aneeshkrishna/coffer.storage;
import aneeshkrishna/coffer.telemetry;
import aneeshkrishna/coffer.iso20022;

# Payload schema for account creation endpoint.
#
# + id - Account UUID
# + accountIdentifier - External IBAN or clearing account number
# + name - Customer name or account title
# + initialBalance - Initial balance string
# + currency - ISO 4217 currency
public type CreateAccountRequest record {|
    string id;
    string accountIdentifier;
    string name;
    string initialBalance = "0.00";
    string currency = "USD";
|};

# Shared singleton application state container.
#
# + ledgerEngine - Double-entry ledger subsystem
# + paymentRouter - Multi-rail router subsystem
# + riskEngine - Risk and fraud screening subsystem
# + nettingEngine - Multilateral netting subsystem
# + storageEngine - WAL durability and Merkle storage subsystem
# + telemetryEngine - OpenMetrics telemetry subsystem
# + sagaOrchestrator - Saga distributed payment coordinator
public class AppState {
    public final ledger:LedgerEngine ledgerEngine = new ();
    public final routing:PaymentRouter paymentRouter = new ();
    public final risk:RiskEngine riskEngine = new ();
    public final netting:NettingEngine nettingEngine = new ();
    public final storage:StorageEngine storageEngine = new ();
    public final telemetry:TelemetryEngine telemetryEngine = new ();
    public final saga:PaymentSagaOrchestrator sagaOrchestrator;

    # Initializes state and wires dependencies.
    public isolated function init() {
        self.sagaOrchestrator = saga:createSagaOrchestrator(
            self.ledgerEngine,
            self.paymentRouter,
            self.riskEngine
        );
    }
}

# Global application state instance.
final AppState globalState = new ();

# Configurable gateway HTTP listening port.
configurable int gatewayPort = 8990;

# HTTP REST API Gateway service for Coffer.
service /api/v1 on new http:Listener(gatewayPort) {

    # Health check endpoint returning system status.
    #
    # + return - Status record
    resource function get health() returns json {
        return {
            "status": "UP",
            "service": "coffer",
            "version": "0.1.0",
            "activeRails": ["FEDNOW", "SEPA_INSTANT", "RTP", "ACH", "SWIFT", "INTERNAL"]
        };
    }

    # OpenMetrics / Prometheus telemetry scrape endpoint.
    #
    # + return - Formatted metrics text payload
    resource function get metrics() returns http:Response {
        string text = globalState.telemetryEngine.scrapeMetrics();
        http:Response res = new;
        res.setTextPayload(text, "text/plain; version=0.0.4");
        return res;
    }

    # Submits a new payment transfer intent to the gateway.
    #
    # + intent - Incoming transfer payload
    # + return - Transaction record or error response
    resource function post transfers(@http:Payload types:TransferIntent intent) returns http:Response|error {
        int nowEpochNs = 1730550000000000;
        types:TransactionRecord|error tx = globalState.sagaOrchestrator.execute(intent, nowEpochNs);

        http:Response res = new;

        if tx is types:IdempotencyConflictError {
            res.statusCode = 409;
            res.setJsonPayload({ "error": tx.message() });
            return res;
        }

        if tx is error {
            res.statusCode = 400;
            res.setJsonPayload({ "error": tx.message() });
            return res;
        }

        // Record into WAL and telemetry
        _ = globalState.storageEngine.getWalManager().append(
            storage:WAL_TX_SETTLED,
            tx.id + ":" + tx.status.toString(),
            nowEpochNs
        );

        if tx.status == types:SETTLED {
            globalState.telemetryEngine.getRegistry().recordSettled(1000, 450);
        } else if tx.status == types:FAILED {
            globalState.telemetryEngine.getRegistry().recordFailed();
        } else if tx.status == types:QUARANTINED {
            globalState.telemetryEngine.getRegistry().recordQuarantined();
        }

        // Generate ISO 20022 pacs.008 XML
        xml|types:ISOValidationError isoDoc = iso20022:createPacs008Document(
            intent,
            "MSG_" + tx.id,
            "2026-11-02T13:45:00Z",
            tx.activeRail
        );
        string isoXmlStr = isoDoc is xml ? isoDoc.toString() : "";

        res.statusCode = 200;
        res.setJsonPayload({
            "transaction": tx,
            "iso20022Xml": isoXmlStr
        });
        return res;
    }

    # Retrieves an existing transaction by UUID.
    #
    # + id - Transaction UUID
    # + return - TransactionRecord or 404
    resource function get transfers/[string id]() returns http:Response {
        types:TransactionRecord|error tx = globalState.sagaOrchestrator.getTransaction(id);
        http:Response res = new;
        if tx is error {
            res.statusCode = 404;
            res.setJsonPayload({ "error": tx.message() });
            return res;
        }
        res.statusCode = 200;
        res.setJsonPayload(tx);
        return res;
    }

    # Lists all transactions.
    #
    # + return - Array of TransactionRecords
    resource function get transfers() returns types:TransactionRecord[] {
        return globalState.sagaOrchestrator.getAllTransactions();
    }

    # Creates and registers a new ledger account.
    #
    # + req - Typed Account creation request
    # + return - Account snapshot or error
    resource function post accounts(@http:Payload CreateAccountRequest req) returns http:Response|error {
        types:Currency cur = req.currency == "EUR" ? types:EUR : types:USD;

        types:Account|error acc = ledger:createAccount(
            req.id,
            req.accountIdentifier,
            req.name,
            types:ASSET,
            types:CUSTOMER_CHECKING,
            cur,
            req.initialBalance,
            1730550000000000
        );

        http:Response res = new;
        if acc is error {
            res.statusCode = 400;
            res.setJsonPayload({ "error": acc.message() });
            return res;
        }

        error? regErr = globalState.ledgerEngine.registerAccount(acc);
        if regErr is error {
            res.statusCode = 400;
            res.setJsonPayload({ "error": regErr.message() });
            return res;
        }

        res.statusCode = 201;
        res.setJsonPayload(acc);
        return res;
    }

    # Retrieves an account snapshot by UUID.
    #
    # + id - Account UUID
    # + return - Account snapshot or 404
    resource function get accounts/[string id]() returns http:Response {
        types:Account|error acc = globalState.ledgerEngine.getAccount(id);
        http:Response res = new;
        if acc is error {
            res.statusCode = 404;
            res.setJsonPayload({ "error": acc.message() });
            return res;
        }
        res.statusCode = 200;
        res.setJsonPayload(acc);
        return res;
    }

    # Lists all registered ledger accounts.
    #
    # + return - Array of Accounts
    resource function get accounts() returns types:Account[] {
        return globalState.ledgerEngine.getAllAccounts();
    }

    # Retrieves committed journal history.
    #
    # + return - Array of JournalBatches
    resource function get ledger/journal() returns types:JournalBatch[] {
        return globalState.ledgerEngine.getJournal();
    }

    # Submits a bilateral payment obligation into the netting cycle buffer.
    #
    # + debt - BilateralDebt record
    # + return - Confirmation response
    resource function post netting/accumulate(@http:Payload types:BilateralDebt debt) returns json {
        globalState.nettingEngine.accumulateDebt(debt);
        return {
            "status": "ACCUMULATED",
            "debt": debt
        };
    }

    # Triggers multilateral netting optimization cycle.
    #
    # + cycleId - Unique cycle identifier
    # + return - NettingCycleResult or error
    resource function post netting/cycles(string cycleId = "CYC_AUTO") returns http:Response {
        var cycleRes = globalState.nettingEngine.executeCycle(cycleId, types:USD);
        http:Response res = new;
        if cycleRes is error {
            res.statusCode = 400;
            res.setJsonPayload({ "error": cycleRes.message() });
            return res;
        }
        res.statusCode = 200;
        res.setJsonPayload(cycleRes);
        return res;
    }

    # Lists quarantined items awaiting review.
    #
    # + return - Array of QuarantinedItem records
    resource function get risk/quarantine() returns risk:QuarantinedItem[] {
        return globalState.riskEngine.getQuarantineStore().getAll();
    }

    # Releases a quarantined item upon compliance approval.
    #
    # + id - Quarantined transaction UUID
    # + return - Released item snapshot or error
    resource function post risk/quarantine/[string id]/release() returns http:Response {
        var itemRes = globalState.riskEngine.getQuarantineStore().release(id);
        http:Response res = new;
        if itemRes is error {
            res.statusCode = 404;
            res.setJsonPayload({ "error": itemRes.message() });
            return res;
        }
        res.statusCode = 200;
        res.setJsonPayload(itemRes);
        return res;
    }
}
