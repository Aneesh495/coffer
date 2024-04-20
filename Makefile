# Coffer: Distributed High-Assurance Payment Orchestration and Liquidity Settlement Fabric
# Root Build, Automation, and Verification Makefile

BAL ?= bal
CC ?= clang
PYTHON ?= python3
CFLAGS ?= -O3 -Wall -Wextra -pedantic -std=c11
C_SRC_DIR := $(CURDIR)/c_src
BIN_DIR := $(CURDIR)/bin
DOCS_DIR := $(CURDIR)/docs
TEST_DIR := $(CURDIR)/tests

.PHONY: all build build-c test unit-tests integration-tests regression-tests run bench verify check-dashes clean

all: build

build: build-c
	@echo "Compiling Ballerina Coffer distribution..."
	@$(BAL) build

build-c:
	@mkdir -p $(BIN_DIR)
	@echo "Compiling native C acceleration engines..."
	@if [ -d "$(C_SRC_DIR)/fixedpoint" ]; then \
		$(CC) $(CFLAGS) -c $(C_SRC_DIR)/fixedpoint/fixed_point.c -o $(BIN_DIR)/fixed_point.o; \
	fi
	@if [ -d "$(C_SRC_DIR)/netting" ]; then \
		$(CC) $(CFLAGS) -c $(C_SRC_DIR)/netting/netting_engine.c -o $(BIN_DIR)/netting_engine.o; \
	fi
	@if [ -d "$(C_SRC_DIR)/merkle" ]; then \
		$(CC) $(CFLAGS) -c $(C_SRC_DIR)/merkle/merkle_tree.c -o $(BIN_DIR)/merkle_tree.o; \
	fi
	@if [ -f "$(BIN_DIR)/fixed_point.o" ] && [ -f "$(BIN_DIR)/netting_engine.o" ] && [ -f "$(BIN_DIR)/merkle_tree.o" ]; then \
		ar rcs $(BIN_DIR)/libcoffer_accel.a $(BIN_DIR)/fixed_point.o $(BIN_DIR)/netting_engine.o $(BIN_DIR)/merkle_tree.o; \
		echo "Archived $(BIN_DIR)/libcoffer_accel.a successfully."; \
	fi
	@if [ -d "$(C_SRC_DIR)/bench" ]; then \
		$(CC) $(CFLAGS) $(C_SRC_DIR)/bench/coffer_bench.c $(C_SRC_DIR)/bench/hdr_histogram.c -o $(BIN_DIR)/coffer-bench -lpthread; \
		echo "Compiled $(BIN_DIR)/coffer-bench successfully."; \
	fi

test:
	@echo "Executing complete Ballerina test harness..."
	@$(BAL) test

unit-tests:
	@echo "Executing Ballerina module unit tests..."
	@$(BAL) test

integration-tests:
	@echo "Executing end-to-end integration test matrix..."
	@./tests/integration/run_integration.sh

regression-tests:
	@echo "Executing documented bug regression test matrix..."
	@./tests/regressions/run_regressions.sh

run: build
	@echo "Launching Coffer distributed payment gateway daemon..."
	@$(BAL) run

bench: build
	@echo "Running Coffer benchmark suite..."
	@./scripts/bench_50k.sh

verify: test check-dashes
	@echo "All verification checks passed with zero errors."

check-dashes:
	@echo "Verifying zero em dashes across repository..."
	@if grep -rn --exclude=Makefile --exclude="*.jar" --exclude-dir=target --exclude-dir=.git "—" . 2>/dev/null; then \
		echo "ERROR: Em dashes detected! Failing verification."; \
		exit 1; \
	elif grep -rn --exclude=Makefile --exclude="*.jar" --exclude-dir=target --exclude-dir=.git "–" . 2>/dev/null; then \
		echo "ERROR: En dashes detected! Failing verification."; \
		exit 1; \
	else \
		echo "Verification clean: zero em or en dashes detected."; \
	fi

clean:
	@rm -rf $(BIN_DIR) target build *.wal *.snap *.log data storage_data
	@echo "Cleaned all build, runtime, and target artifacts."
