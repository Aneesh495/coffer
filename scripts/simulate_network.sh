#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Coffer Multi-Bank Clearing Network Simulation Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " COFFER INTERBANK PAYMENT FABRIC NETWORK SIMULATION"
echo "================================================================================"

cd "${ROOT_DIR}"

TRANSFERS="${1:-1000}"
echo "Running multi-bank interbank network traffic simulation (${TRANSFERS} transactions)..."
PYTHONPATH="${ROOT_DIR}/python" python3 "${ROOT_DIR}/python/simulator/bank_network_sim.py" --transfers "${TRANSFERS}" --mock

echo ""
echo "Running intraday multilateral netting and liquidity stress experiment..."
PYTHONPATH="${ROOT_DIR}/python" python3 "${ROOT_DIR}/python/simulator/liquidity_stress_sim.py"

echo "================================================================================"
echo " SIMULATION RUN COMPLETED SUCCESSFULLY"
echo "================================================================================"
