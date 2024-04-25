// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Universal domain types, enums, records, and schemas for Coffer.
# This module defines the canonical representations for financial currencies,
# payment rails, transaction lifecycle states, double-entry accounts,
# risk evaluations, and ISO 20022 financial payload envelopes.

# ISO 4217 Currency Codes supported by Coffer.
public enum Currency {
    USD = "USD",
    EUR = "EUR",
    GBP = "GBP",
    JPY = "JPY",
    CHF = "CHF",
    CAD = "CAD",
    AUD = "AUD",
    SGD = "SGD"
}

# Real-time and batch settlement rails coordinated by Coffer.
public enum PaymentRail {
    FEDNOW = "FEDNOW",
    SEPA_INSTANT = "SEPA_INSTANT",
    RTP = "RTP",
    ACH = "ACH",
    SWIFT = "SWIFT",
    INTERNAL = "INTERNAL"
}

# Finite State Machine states for payment transaction lifecycle.
public enum TransactionStatus {
    INITIATED = "INITIATED",
    RISK_EVALUATED = "RISK_EVALUATED",
    QUARANTINED = "QUARANTINED",
    ROUTED = "ROUTED",
    RESERVED = "RESERVED",
    DISPATCHED = "DISPATCHED",
    SETTLED = "SETTLED",
    FAILED = "FAILED",
    COMPENSATED = "COMPENSATED"
}

# Entry direction for double-entry bookkeeping postings.
public enum EntryDirection {
    DEBIT = "DEBIT",
    CREDIT = "CREDIT"
}

# Fundamental accounting classifications under GAAP and IFRS.
public enum AccountType {
    ASSET = "ASSET",
    LIABILITY = "LIABILITY",
    EQUITY = "EQUITY",
    REVENUE = "REVENUE",
    EXPENSE = "EXPENSE"
}

# Granular account categories for banking and treasury management.
public enum AccountCategory {
    CUSTOMER_CHECKING = "CUSTOMER_CHECKING",
    CUSTOMER_SAVINGS = "CUSTOMER_SAVINGS",
    SETTLEMENT_CLEARING = "SETTLEMENT_CLEARING",
    FEE_INCOME = "FEE_INCOME",
    INTEREST_EXPENSE = "INTEREST_EXPENSE",
    ESCROW_HOLD = "ESCROW_HOLD",
    NOSTRO = "NOSTRO",
    VOSTRO = "VOSTRO"
}

# Operating status of a ledger account.
public enum AccountStatus {
    ACTIVE = "ACTIVE",
    FROZEN = "FROZEN",
    RESTRICTED = "RESTRICTED",
    CLOSED = "CLOSED"
}

# Risk evaluation decisions emitted by the compliance engine.
public enum RiskDecision {
    APPROVED = "APPROVED",
    FLAGGED = "FLAGGED",
    QUARANTINED = "QUARANTINED",
    REJECTED = "REJECTED"
}

# Specific risk triggers identified during transaction inspection.
public enum RiskTrigger {
    TRIGGER_NONE = "TRIGGER_NONE",
    HIGH_VELOCITY = "HIGH_VELOCITY",
    OFF_HOURS = "OFF_HOURS",
    SANCTION_MATCH = "SANCTION_MATCH",
    UNUSUAL_VOLUME = "UNUSUAL_VOLUME",
    MULE_BURST = "MULE_BURST",
    STRUCTURING_DETECTED = "STRUCTURING_DETECTED"
}

# Current state of a multi-rail settlement clearing cycle.
public enum NettingStatus {
    NETTING_OPEN = "NETTING_OPEN",
    NETTING_CALCULATING = "NETTING_CALCULATING",
    NETTING_OPTIMIZED = "NETTING_OPTIMIZED",
    NETTING_SETTLED = "NETTING_SETTLED",
    NETTING_COLLATERAL_DEFICIT = "NETTING_COLLATERAL_DEFICIT"
}

# Saga distributed transaction execution status.
public enum SagaStatus {
    SAGA_NOT_STARTED = "SAGA_NOT_STARTED",
    SAGA_IN_PROGRESS = "SAGA_IN_PROGRESS",
    SAGA_COMPLETED = "SAGA_COMPLETED",
    SAGA_COMPENSATING = "SAGA_COMPENSATING",
    SAGA_COMPENSATED = "SAGA_COMPENSATED",
    SAGA_FAILED = "SAGA_FAILED"
}

# Bank or financial institution identification.
#
# + bic - ISO 9362 Business Identifier Code
# + routingNumber - Domestic national clearing routing identifier
# + name - Full legal corporate institution name
# + countryCode - ISO 3166-1 alpha-2 country identifier
public type FinancialInstitution record {|
    string bic;
    string routingNumber;
    string name;
    string countryCode;
|};

# Counterparty identification in a payment transaction.
#
# + id - Internal customer or party UUID
# + name - Natural person or corporate legal title
# + accountIdentifier - External IBAN or domestic account number
# + institution - Servicing banking institution
# + email - Optional electronic contact address
# + physicalAddress - Optional registered street address
public type Party record {|
    string id;
    string name;
    string accountIdentifier;
    FinancialInstitution institution;
    string? email = ();
    string? physicalAddress = ();
|};

# Customer payment transfer intent submitted to the gateway.
#
# + id - Unique system-wide transfer UUID
# + idempotencyKey - Client deduplication key
# + endToEndId - ISO 20022 EndToEndId reference
# + debtor - Originating sender party
# + creditor - Destination beneficiary party
# + amount - Decimal numeric transfer amount as string
# + currency - ISO 4217 currency designation
# + remittanceInformation - Unstructured narrative payment reference
# + preferredRail - Client requested settlement rail
# + allowFallback - Permit automated smart failover if rail fails
# + maxFeeCents - Fee ceiling cap in minor currency units
# + createdAtEpochNs - Instruction creation timestamp in nanoseconds
# + deadlineEpochNs - Strict settlement cut-off deadline in nanoseconds
public type TransferIntent record {|
    string id;
    string idempotencyKey;
    string endToEndId;
    Party debtor;
    Party creditor;
    string amount;
    Currency currency;
    string remittanceInformation;
    PaymentRail? preferredRail = ();
    boolean allowFallback = true;
    int maxFeeCents = 10000;
    int createdAtEpochNs;
    int deadlineEpochNs;
|};

# Real-time state of a transaction inside the orchestration engine.
#
# + id - Internal transaction UUID
# + idempotencyKey - Idempotent submission key
# + endToEndId - End-to-end reference
# + status - Current lifecycle status
# + intent - Immutable transfer intent record
# + activeRail - Settlement rail assigned or attempted
# + riskScore - Computed anomaly score between 0 and 100
# + riskDecision - Gatekeeper compliance verdict
# + riskTriggers - Trigger reasons flagged by evaluation
# + holdId - Ledger reservation hold UUID
# + railReference - External clearing rail confirmation number
# + settlementJournalId - Committed double-entry journal batch identifier
# + failureReason - Detailed diagnostic description on failure
# + createdAtEpochNs - Transaction initialization timestamp
# + updatedAtEpochNs - Transaction state transition timestamp
public type TransactionRecord record {|
    string id;
    string idempotencyKey;
    string endToEndId;
    TransactionStatus status;
    TransferIntent intent;
    PaymentRail activeRail;
    int riskScore;
    RiskDecision riskDecision;
    string[] riskTriggers;
    string? holdId = ();
    string? railReference = ();
    string? settlementJournalId = ();
    string? failureReason = ();
    int createdAtEpochNs;
    int updatedAtEpochNs;
|};

# Individual ledger entry posting adhering to double-entry standards.
#
# + entryId - Monotonic or UUID posting identifier
# + transactionId - Associated transfer transaction ID
# + accountId - Target chart of accounts identifier
# + direction - Debit or Credit posting direction
# + amount - Scaled decimal monetary amount as string
# + currency - ISO 4217 denomination
# + postedAtEpochNs - Timestamp of entry commitment
# + description - Audit narrative describing transaction leg
public type LedgerEntry record {|
    string entryId;
    string transactionId;
    string accountId;
    EntryDirection direction;
    string amount;
    Currency currency;
    int postedAtEpochNs;
    string description;
|};

# Balanced atomic batch of ledger postings.
#
# + batchId - Unique journal batch identifier
# + transactionId - Associated transfer transaction identifier
# + entries - Array of ledger postings comprising the transaction
# + createdAtEpochNs - Batch creation timestamp
# + merkleRoot - Cryptographic SHA-256 Merkle root hash
# + balanced - Strict assertion that total debits equal total credits
public type JournalBatch record {|
    string batchId;
    string transactionId;
    LedgerEntry[] entries;
    int createdAtEpochNs;
    string merkleRoot;
    boolean balanced;
|};

# Chart of accounts record maintaining balance snapshots.
#
# + id - Ledger account UUID
# + accountIdentifier - External account or IBAN number
# + name - Account title or holder moniker
# + accountType - High level asset, liability, equity, or revenue class
# + category - Granular banking operational classification
# + currency - Account base denomination
# + status - Operating status of account
# + settledBalance - Confirmed posted balance
# + pendingHoldsBalance - Balance held in reserved commitments
# + availableBalance - Funds immediately spendable: settled minus holds
# + version - Optimistic concurrency locking sequence number
# + createdAtEpochNs - Account creation timestamp
# + updatedAtEpochNs - Last balance mutation timestamp
public type Account record {|
    string id;
    string accountIdentifier;
    string name;
    AccountType accountType;
    AccountCategory category;
    Currency currency;
    AccountStatus status;
    string settledBalance;
    string pendingHoldsBalance;
    string availableBalance;
    int version;
    int createdAtEpochNs;
    int updatedAtEpochNs;
|};

# Escrow hold record for pending authorizations.
#
# + holdId - Unique hold identifier
# + accountId - Debited account identifier
# + transactionId - Associated transaction reference
# + amount - Amount held in escrow
# + currency - Hold denomination
# + active - True if hold is currently reserved
# + expiresAtEpochNs - Timestamp after which hold expires automatically
public type AccountHold record {|
    string holdId;
    string accountId;
    string transactionId;
    string amount;
    Currency currency;
    boolean active;
    int expiresAtEpochNs;
|};

# Performance and health metrics for a connected payment rail.
#
# + rail - Target payment rail identifier
# + isAvailable - Operational online flag
# + latencyP99Ms - Observed p99 latency in milliseconds
# + feePercentage - Variable volume fee percentage
# + fixedFeeCents - Fixed per-transaction fee in minor units
# + failureCount - Rolling count of failed requests
# + consecutiveErrors - Monotonic count of consecutive timeouts
# + circuitTripThreshold - Error count triggering circuit trip
# + circuitOpen - True if circuit breaker is tripped open
# + circuitHalfOpenEpochMs - Epoch timestamp for half-open probe attempt
public type RailHealth record {|
    PaymentRail rail;
    boolean isAvailable;
    int latencyP99Ms;
    decimal feePercentage;
    int fixedFeeCents;
    int failureCount;
    int consecutiveErrors;
    int circuitTripThreshold;
    boolean circuitOpen;
    int circuitHalfOpenEpochMs;
|};

# Result of dynamic rail selection.
#
# + chosenRail - Payment rail selected by cost, speed, and health criteria
# + estimatedLatencyMs - Projected clearing latency
# + estimatedFeeCents - Projected fee in minor currency units
# + routingRationale - Audit explanation justifying selection
# + fallbackOrder - Ordered failover rails if chosen rail fails
public type RoutingDecision record {|
    PaymentRail chosenRail;
    int estimatedLatencyMs;
    int estimatedFeeCents;
    string routingRationale;
    PaymentRail[] fallbackOrder;
|};

# Step within a distributed Saga workflow.
#
# + stepName - Unique descriptive name of workflow step
# + status - Current step execution status
# + executionPayload - Serialized forward execution context
# + compensationPayload - Serialized reverse compensating transaction context
# + startedAtEpochNs - Step invocation timestamp
# + completedAtEpochNs - Step completion timestamp
public type SagaStep record {|
    string stepName;
    string status;
    string? executionPayload = ();
    string? compensationPayload = ();
    int startedAtEpochNs;
    int completedAtEpochNs;
|};

# Multilateral netting participant obligation summary.
#
# + participantBic - Unique clearing participant BIC
# + netDebitAmount - Total gross outgoing payments
# + netCreditAmount - Total gross incoming payments
# + netPosition - Net obligation: positive for net creditor, negative for net debtor
# + isCreditor - True if participant receives funds at cycle settlement
public type NetObligation record {|
    string participantBic;
    string netDebitAmount;
    string netCreditAmount;
    string netPosition;
    boolean isCreditor;
|};

# Bilateral debt record between two participants.
#
# + debtorBic - Debtor bank BIC
# + creditorBic - Creditor bank BIC
# + amount - Raw bilateral obligation amount
# + currency - ISO 4217 currency
public type BilateralDebt record {|
    string debtorBic;
    string creditorBic;
    string amount;
    Currency currency;
|};
