#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Master Verification Harness: Enforces zero-defect quality across all subsystems

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " COFFER MASTER SYSTEM VERIFICATION HARNESS"
echo "================================================================================"

cd "${ROOT_DIR}"

echo "[Step 1/6] Verifying Zero Em and En Dashes Across Entire Repository..."
make check-dashes

echo "[Step 2/6] Compiling Native C Engines and Executing Unit Tests..."
make build-c
clang -O3 -Wall -Wextra c_src/fixedpoint/test_fixed_point.c bin/libcoffer_accel.a -o bin/test_fp
./bin/test_fp
clang -O3 -Wall -Wextra c_src/netting/test_netting.c bin/libcoffer_accel.a -o bin/test_net
./bin/test_net
clang -O3 -Wall -Wextra c_src/merkle/test_merkle.c bin/libcoffer_accel.a -o bin/test_merkle
./bin/test_merkle

echo "[Step 3/6] Running Complete Ballerina Test Suite (All 11 Modules)..."
bal test

echo "[Step 4/6] Executing Documented Bug Regression Test Matrix (All 5 Bugs)..."
./tests/regressions/run_regressions.sh

echo "[Step 5/6] Executing System Integration Test Matrix..."
./tests/integration/run_integration.sh

echo "[Step 6/6] Executing Python SDK and Simulator Unit Tests..."
PYTHONPATH="${ROOT_DIR}/python" python3 -m unittest discover -s python/tests -v

echo "================================================================================"
echo " MASTER VERIFICATION PASSED: ALL SUBSYSTEMS VERIFIED WITH ZERO ERRORS"
echo "================================================================================"
