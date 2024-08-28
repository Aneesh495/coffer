#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Coffer 50,000 Transaction End-to-End Benchmark Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " COFFER HIGH-THROUGHPUT BENCHMARK HARNESS (50,000 TRANSACTIONS)"
echo "================================================================================"

cd "${ROOT_DIR}"

echo "[Stage 1/2] Compiling and Executing Native C Fixed-Point & Merkle Tree Benchmark..."
make build-c
"${ROOT_DIR}/bin/coffer-bench" -t 8 -n 50000

echo "[Stage 2/2] Running Python Concurrent Load Tester Benchmark (5,000 mock concurrent ops)..."
PYTHONPATH="${ROOT_DIR}/python" python3 "${ROOT_DIR}/python/bench/load_tester.py" --requests 5000 --concurrency 8 --mock

echo "================================================================================"
echo " BENCHMARK SUITE EXECUTED SUCCESSFULLY"
echo "================================================================================"
