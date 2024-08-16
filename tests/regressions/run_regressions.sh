#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Coffer Documented Bug Regression Test Suite Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "================================================================================"
echo " COFFER DOCUMENTED BUG REGRESSION SUITE RUNNER"
echo "================================================================================"
echo " Executing 5 documented bug regression tests:"
echo "   - Bug #1: Fixed-point decimal formatting truncation error"
echo "   - Bug #2: INTERNAL book transfer rail eligibility leak in interbank candidate pool"
echo "   - Bug #3: Substring containment false positive in sanctions screening"
echo "   - Bug #4: Net-zero participant collateral deficit check avoidance"
echo "   - Bug #5: Saga idempotency replay prevention of duplicate journal executions"
echo "--------------------------------------------------------------------------------"

cd "${ROOT_DIR}"
bal test --tests "testRegressionBug*"

echo "================================================================================"
echo " REGRESSION VERIFICATION COMPLETE: ALL 5 BUG REGRESSIONS PRESERVED AND PASSING"
echo "================================================================================"
