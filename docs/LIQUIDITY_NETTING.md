# Multilateral Netting and Liquidity Optimization Engine

## 1. Mathematical Formulation

Real-time Gross Settlement (RTGS) requires every single payment to be funded individually and immediately with central bank liquidity. During peak trading hours, this imposes immense liquidity friction on financial institutions.

Coffer integrates an intraday **Multilateral Netting Engine** that bundles bilateral payment obligations across clearing participants and computes a single net settlement figure per bank.

For a network of $P$ participating institutions clearing $N$ bilateral payment obligations:

### Net Position Calculation:
For participant $i$:

$$\text{NetPosition}_i = \sum_{j=1}^{P} \text{Inflow}_{j \to i} - \sum_{k=1}^{P} \text{Outflow}_{i \to k}$$

- If $\text{NetPosition}_i > 0$, participant $i$ is a **Net Creditor** and receives liquidity at settlement.
- If $\text{NetPosition}_i < 0$, participant $i$ is a **Net Debtor** and must deliver liquidity to the clearing house.
- If $\text{NetPosition}_i = 0$, participant $i$ is **Net Balanced** and requires zero liquidity.

### Zero-Sum Conservation Proof:
Because every payment obligation has exactly one debtor and one creditor:

$$\sum_{i=1}^{P} \text{NetPosition}_i \equiv 0.00$$

---

## 2. Liquidity Savings Ratio

The economic efficiency of a netting cycle is quantified by the **Liquidity Savings Ratio ($\eta$)**:

$$\text{GrossVolume} = \sum_{m=1}^{N} \text{ObligationAmount}_m$$

$$\text{NetSettlementVolume} = \sum_{i \in \text{Creditors}} \text{NetPosition}_i$$

$$\eta = 1 - \frac{\text{NetSettlementVolume}}{\text{GrossVolume}}$$

In empirical simulation across 10 commercial banks processing 1,200 obligations, Coffer achieves a **95%+ liquidity savings ratio**, freeing up millions in intraday bank reserves.

```
+-------------------------------------------------------------------------------+
|             MULTILATERAL NETTING CYCLE OPTIMIZATION FLOW                      |
+-------------------------------------------------------------------------------+
|  GROSS OBLIGATIONS (1,200 txs)  --->  $1,248,862,291.34                       |
|  CYCLE COMPUTATION MATRIX       --->  Multilateral Cycle Graph Cancellation   |
|  NET SETTLEMENT VOLUME REQUIRED --->     $55,739,165.63                       |
|  INTRADAY LIQUIDITY FREED UP    --->  $1,193,123,125.71 (95.54% Savings)      |
+-------------------------------------------------------------------------------+
```

---

## 3. Collateral Management and Dynamic Unwinding

Prior to cycle finalization, the `CollateralManager` evaluates whether every net debtor bank maintains sufficient posted margin:

$$\text{PostedCollateral}_i + \text{CreditLimit}_i \ge |\text{NetPosition}_i|$$

### Dynamic Bilateral Unwinding:
If a participant bank suffers an intraday liquidity shock and fails the collateral constraint:
1. The engine avoids cancelling the entire session.
2. It initiates the **Coffer Dynamic Bilateral Unwind Algorithm**.
3. It systematically extracts obligations where the deficit bank is debtor, recomputing net positions iteratively until all remaining participants satisfy the solvency constraint.
4. The remaining balanced cycle settles cleanly, containing systemic contagion.
