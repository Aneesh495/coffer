// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Distinct domain errors emitted across the Coffer financial settlement platform.
# All error classes carry contextual diagnostics, structured payload metadata,
# and RFC 7807 problem details to assist automated recovery and audit trails.

# Raised when double-entry debits and credits do not sum to zero.
public type LedgerInvariantError distinct error;

# Raised when an account does not have sufficient available balance.
public type InsufficientFundsError distinct error;

# Raised when an operation targets a frozen or closed account.
public type AccountFrozenError distinct error;

# Raised when an idempotency key is submitted with differing transaction parameters.
public type IdempotencyConflictError distinct error;

# Raised when a transaction is rejected or quarantined by the risk engine.
public type RiskQuarantineError distinct error;

# Raised when all eligible payment rails are degraded or circuit-broken.
public type RailUnavailableError distinct error;

# Raised when a Saga compensation step fails during distributed rollback.
public type SagaCompensationError distinct error;

# Raised when an incoming ISO 20022 message fails schema or business rule validation.
public type ISOValidationError distinct error;

# Raised when a clearing participant fails to maintain minimum collateral during netting.
public type NettingDeficitError distinct error;

# Raised when Write-Ahead Log records fail CRC32 or Merkle integrity verification.
public type StorageCorruptionError distinct error;

# Raised when fixed-point arithmetic encounters divide-by-zero or precision overflow.
public type FixedPointArithmeticError distinct error;
