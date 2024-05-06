#!/usr/bin/env bash
# Coffer Bug Regression Test Orchestrator
set -euo pipefail

echo "============================================================"
echo "           COFFER BUG REGRESSION TEST SUITE                 "
echo "============================================================"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"

echo "Executing regression suite via Ballerina test engine..."
bal test --tests "coffer:testRegression*"

echo "All documented regression tests passed cleanly."
