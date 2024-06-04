// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;

@test:Config {}
function testHistogramBucketDistribution() {
    HdrHistogram hist = new ();

    // Record latencies: 50us, 120us, 450us, 800us, 2000us
    hist.recordLatency(50);
    hist.recordLatency(120);
    hist.recordLatency(450);
    hist.recordLatency(800);
    hist.recordLatency(2000);

    map<int> summary = hist.getSummary();
    test:assertEquals(summary["count"], 5);
    test:assertEquals(summary["max"], 2000);
    test:assertTrue((summary["p50"] ?: 0) >= 450);
    test:assertTrue((summary["p99"] ?: 0) >= 2000);
}

@test:Config {}
function testMetricsRegistryOpenMetricsOutput() {
    MetricsRegistry registry = new ();

    registry.recordSettled(150000, 350); // $1,500.00, 350us
    registry.recordSettled(25000, 120);  // $250.00, 120us
    registry.recordFailed();
    registry.recordQuarantined();

    string metricsText = registry.toOpenMetricsFormat();

    test:assertTrue(metricsText.includes("coffer_settled_transactions_total 2"));
    test:assertTrue(metricsText.includes("coffer_failed_transactions_total 1"));
    test:assertTrue(metricsText.includes("coffer_quarantined_transactions_total 1"));
    test:assertTrue(metricsText.includes("coffer_clearing_volume_cents_total 175000"));
    test:assertTrue(metricsText.includes("coffer_settlement_latency_us{quantile=\"0.5\"}"));
}
