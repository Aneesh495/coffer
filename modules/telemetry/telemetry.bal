// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Master telemetry manager providing OpenMetrics scrape outputs and health checks.
public class TelemetryEngine {
    private final MetricsRegistry registry = new ();

    # Initializes telemetry engine.
    public isolated function init() {
    }

    # Retrieves global metrics registry.
    #
    # + return - MetricsRegistry reference
    public isolated function getRegistry() returns MetricsRegistry {
        return self.registry;
    }

    # Produces Prometheus text scrape response.
    #
    # + return - Formatted metric text
    public isolated function scrapeMetrics() returns string {
        return self.registry.toOpenMetricsFormat();
    }
}
