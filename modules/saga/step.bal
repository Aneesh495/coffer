// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Execution context passed across forward Saga steps.
#
# + transactionId - Target transaction identifier
# + intent - Customer transfer intent
# + riskScore - Risk score computed
# + routingDecision - Selected payment rail decision
# + holdId - Ledger reservation hold UUID
# + railReference - External clearing rail confirmation number
# + journalBatchId - Committed journal batch identifier
# + isSuccess - Step status indicator
# + errorMessage - Diagnostic error string if failed
public type SagaContext record {|
    string transactionId;
    types:TransferIntent intent;
    int riskScore = 0;
    types:RoutingDecision? routingDecision = ();
    string? holdId = ();
    string? railReference = ();
    string? journalBatchId = ();
    boolean isSuccess = false;
    string? errorMessage = ();
|};

# Standard names for lifecycle steps in the payment clearing Saga.
public const string STEP_RISK = "STEP_RISK_EVALUATION";
public const string STEP_ROUTING = "STEP_SMART_ROUTING";
public const string STEP_ESCROW_HOLD = "STEP_ESCROW_HOLD";
public const string STEP_RAIL_DISPATCH = "STEP_RAIL_DISPATCH";
public const string STEP_LEDGER_POSTING = "STEP_LEDGER_POSTING";
