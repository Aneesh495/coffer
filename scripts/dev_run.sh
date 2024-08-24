#!/usr/bin/env bash
# Copyright (c) 2026 Aneesh Krishna
# Licensed under the MIT License. See LICENSE for details.
#
# Development Runner for Coffer Distributed Payment Gateway

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " STARTING COFFER PAYMENT ORCHESTRATION DAEMON"
echo "================================================================================"

cd "${ROOT_DIR}"
mkdir -p data/wal data/snapshots

echo "Initializing native C acceleration libraries..."
make build-c

echo "Bootstrapping Coffer distribution on ports:"
echo "   - REST Gateway API : http://127.0.0.1:8990"
echo "   - WebSocket Feed   : ws://127.0.0.1:8991"
echo "   - Admin Recon API  : http://127.0.0.1:8992"
echo "   - Metrics Exporter : http://127.0.0.1:8990/metrics"
echo "--------------------------------------------------------------------------------"

bal run
