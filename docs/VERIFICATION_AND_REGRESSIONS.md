# Zero-Defect Verification Framework and Regression History

## 1. Quality Engineering Standards

Coffer enforces a zero-defect engineering standard. Every core primitive is subjected to:
1. Strict static typing and isolation checks in Ballerina 2201.
2. Clang `-O3 -Wall -Wextra -pedantic` native compilation checks.
3. Automated verification of zero em or en dashes across all files.
4. Permanent preservation of every encountered bug as a regression test.

Whenever a defect is uncovered during development, the following lifecycle is mandatory:
1. **Root Cause Analysis (RCA)**: The underlying theoretical flaw is documented.
2. **Reproduction Test**: A failing unit or integration test is committed that reproduces the defect.
3. **Engine Remediation**: The code is refactored to eliminate the bug without side effects.
4. **Permanent Test Preservation**: The test case is added to `tests/test_regressions.bal` to ensure the bug never resurfaces.

---

## 2. Documented Bug Regression Log

### Bug #1: Fixed-Point Decimal Formatting Truncation Error
- **Symptom**: Values like `9999.88` were formatted as `10000.88`.
- **Root Cause**: In `fixedpoint:formatFinancial()`, casting a decimal quotient directly to `int` performed rounding rather than truncation toward zero prior to formatting the fractional cents component.
- **Fix**: Applied `.floor()` to the quotient before integer casting: `<int>((rounded / factor).floor())`.
- **Test Case**: `testRegressionBugFixedpointTruncation` in `tests/test_regressions.bal`.

---

### Bug #2: INTERNAL Rail Eligibility Leak in Interbank Candidate Pool
- **Symptom**: Interbank payments between distinct financial institutions were incorrectly routed to the zero-fee `INTERNAL` book transfer rail.
- **Root Cause**: The route selector's candidate pool included `INTERNAL` globally without asserting debtor and creditor institutional identity.
- **Fix**: Restricted `INTERNAL` rail eligibility strictly to intra-institution transfers (`debtor.institution.bic == creditor.institution.bic`).
- **Test Case**: `testRegressionBugInternalRailEligibility` in `tests/test_regressions.bal`.

---

### Bug #3: Substring Containment False Positive in Sanctions Screening
- **Symptom**: Searching for common clean names like `"Alice"` matched sanctioned entities such as `"VIKTOR MALICE DRUG CARTEL"`.
- **Root Cause**: The name scanner used string substring containment (`haystack.includes(needle)`), matching substring `"ALICE"` inside the surname `"MALICE"`.
- **Fix**: Replaced substring checking with word-boundary and exact token array matching.
- **Test Case**: `testRegressionBugSanctionsSubstringFalsePositive` in `tests/test_regressions.bal`.

---

### Bug #4: Net-Zero Participant Collateral Deficit False Alarm
- **Symptom**: A participant bank with zero posted collateral was rejected with a `NettingDeficitError` despite having a net-zero settlement position (gross debits equalled gross credits).
- **Root Cause**: The netting cycle optimizer performed collateral margin verification on any participant where `!isCreditor`, failing to check `!isZero(net)`.
- **Fix**: Restricted collateral capacity verification strictly to negative net debit positions where `fixedpoint:compare(net, zero) < 0`.
- **Test Case**: `testRegressionBugNettingZeroPositionCollateral` in `tests/test_regressions.bal`.

---

### Bug #5: Saga Idempotency Replay Duplicate Execution
- **Symptom**: Resubmitting a payment intent with an existing idempotency key deducted the debtor account balance a second time.
- **Root Cause**: The orchestrator verified idempotency after initializing transaction context and did not verify whether previous journal batches had already finalized.
- **Fix**: Added an early idempotency check at Step 0 that validates payload equality and immediately returns the cached `SETTLED` record without dispatching new ledger postings.
- **Test Case**: `testRegressionBugSagaDuplicateExecutionPrevention` in `tests/test_regressions.bal`.

---

## 3. Running the Regression Suite

The documented regression suite is automated via:

```bash
./tests/regressions/run_regressions.sh
```
