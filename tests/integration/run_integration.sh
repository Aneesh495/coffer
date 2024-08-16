#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Coffer End-to-End Integration Test Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "================================================================================"
echo " COFFER SYSTEM INTEGRATION TEST SUITE RUNNER"
echo "================================================================================"

cd "${ROOT_DIR}"

echo "[Step 1/3] Running Ballerina Integration Tests..."
bal test --tests "testIntegration*"

echo "[Step 2/3] Running Python Simulation Integration Tests..."
PYTHONPATH="${ROOT_DIR}/python" python3 "${ROOT_DIR}/python/simulator/bank_network_sim.py" --transfers 250 --mock

echo "[Step 3/3] Running Python Liquidity Stress Simulation..."
PYTHONPATH="${ROOT_DIR}/python" python3 "${ROOT_DIR}/python/simulator/liquidity_stress_sim.py"

echo "================================================================================"
echo " INTEGRATION TEST MATRIX COMPLETED: ALL INTEGRATION SCENARIOS VERIFIED"
echo "================================================================================"
