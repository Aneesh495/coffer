// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Central registry holding system-wide operational and financial counters.
public class MetricsRegistry {
    private int settledTransactionsTotal = 0;
    private int failedTransactionsTotal = 0;
    private int quarantinedTransactionsTotal = 0;
    private int totalGrossVolumeCents = 0;
    private final HdrHistogram settlementLatency = new ();

    # Initializes metrics registry.
    public isolated function init() {
    }

    # Increments settled transactions counter and adds cleared volume.
    #
    # + volumeCents - Cleared transaction amount in minor currency units
    # + latencyUs - Observed clearing latency in microseconds
    public isolated function recordSettled(int volumeCents, int latencyUs) {
        lock {
            self.settledTransactionsTotal = self.settledTransactionsTotal + 1;
            self.totalGrossVolumeCents = self.totalGrossVolumeCents + volumeCents;
            self.settlementLatency.recordLatency(latencyUs);
        }
    }

    # Increments failed transactions counter.
    public isolated function recordFailed() {
        lock {
            self.failedTransactionsTotal = self.failedTransactionsTotal + 1;
        }
    }

    # Increments quarantined transactions counter.
    public isolated function recordQuarantined() {
        lock {
            self.quarantinedTransactionsTotal = self.quarantinedTransactionsTotal + 1;
        }
    }

    # Serializes registry state into standard Prometheus / OpenMetrics text exposition format.
    #
    # + return - OpenMetrics formatted string payload
    public isolated function toOpenMetricsFormat() returns string {
        lock {
            map<int> summary = self.settlementLatency.getSummary();
            string out = "";

            out = out + "# HELP coffer_settled_transactions_total Total number of successfully settled transactions\n";
            out = out + "# TYPE coffer_settled_transactions_total counter\n";
            out = out + "coffer_settled_transactions_total " + self.settledTransactionsTotal.toString() + "\n\n";

            out = out + "# HELP coffer_failed_transactions_total Total number of failed transactions\n";
            out = out + "# TYPE coffer_failed_transactions_total counter\n";
            out = out + "coffer_failed_transactions_total " + self.failedTransactionsTotal.toString() + "\n\n";

            out = out + "# HELP coffer_quarantined_transactions_total Total transactions placed in quarantine\n";
            out = out + "# TYPE coffer_quarantined_transactions_total counter\n";
            out = out + "coffer_quarantined_transactions_total " + self.quarantinedTransactionsTotal.toString() + "\n\n";

            out = out + "# HELP coffer_clearing_volume_cents_total Total settled clearing volume in minor currency cents\n";
            out = out + "# TYPE coffer_clearing_volume_cents_total counter\n";
            out = out + "coffer_clearing_volume_cents_total " + self.totalGrossVolumeCents.toString() + "\n\n";

            out = out + "# HELP coffer_settlement_latency_us Settlement latency quantiles in microseconds\n";
            out = out + "# TYPE coffer_settlement_latency_us summary\n";
            out = out + "coffer_settlement_latency_us{quantile=\"0.5\"} " + (summary["p50"] ?: 0).toString() + "\n";
            out = out + "coffer_settlement_latency_us{quantile=\"0.9\"} " + (summary["p90"] ?: 0).toString() + "\n";
            out = out + "coffer_settlement_latency_us{quantile=\"0.99\"} " + (summary["p99"] ?: 0).toString() + "\n";
            out = out + "coffer_settlement_latency_us_count " + (summary["count"] ?: 0).toString() + "\n";

            return out;
        }
    }

    # Exposes underlying latency histogram.
    #
    # + return - HdrHistogram reference
    public isolated function getHistogram() returns HdrHistogram {
        return self.settlementLatency;
    }
}
