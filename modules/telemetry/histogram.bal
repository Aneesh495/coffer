// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Geometric bucket upper bounds in microseconds for HDR latency tracking.
final readonly & int[] LATENCY_BUCKETS_US = [
    10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000, 250000, 500000, 1000000, 5000000
];

# High Dynamic Range latency histogram recording microsecond latencies.
public class HdrHistogram {
    private int[] bucketCounts = [];
    private int totalCount = 0;
    private int sumMicroseconds = 0;
    private int minMicroseconds = 999999999;
    private int maxMicroseconds = 0;

    # Initializes histogram with pre-allocated zero counters.
    public isolated function init() {
        int idx = 0;
        // Allocate count for each bucket + 1 for overflow
        while idx <= LATENCY_BUCKETS_US.length() {
            self.bucketCounts.push(0);
            idx = idx + 1;
        }
    }

    # Records an observed latency sample in microseconds.
    #
    # + durationUs - Observed latency in microseconds
    public isolated function recordLatency(int durationUs) {
        lock {
            self.totalCount = self.totalCount + 1;
            self.sumMicroseconds = self.sumMicroseconds + durationUs;
            if durationUs < self.minMicroseconds {
                self.minMicroseconds = durationUs;
            }
            if durationUs > self.maxMicroseconds {
                self.maxMicroseconds = durationUs;
            }

            int bucketIdx = 0;
            boolean placed = false;
            while bucketIdx < LATENCY_BUCKETS_US.length() {
                if durationUs <= LATENCY_BUCKETS_US[bucketIdx] {
                    self.bucketCounts[bucketIdx] = self.bucketCounts[bucketIdx] + 1;
                    placed = true;
                    break;
                }
                bucketIdx = bucketIdx + 1;
            }

            if !placed {
                // Overflow bucket
                self.bucketCounts[LATENCY_BUCKETS_US.length()] = self.bucketCounts[LATENCY_BUCKETS_US.length()] + 1;
            }
        }
    }

    # Estimates a target percentile latency in microseconds.
    #
    # + percentile - Desired quantile (e.g. 50.0 for p50, 99.0 for p99)
    # + return - Estimated latency in microseconds
    public isolated function getPercentile(decimal percentile) returns int {
        lock {
            if self.totalCount == 0 {
                return 0;
            }
            decimal threshold = (<decimal>self.totalCount * percentile) / 100.0d;
            int countAcc = 0;
            int idx = 0;

            while idx < LATENCY_BUCKETS_US.length() {
                countAcc = countAcc + self.bucketCounts[idx];
                if <decimal>countAcc >= threshold {
                    return LATENCY_BUCKETS_US[idx];
                }
                idx = idx + 1;
            }

            return self.maxMicroseconds;
        }
    }

    # Returns statistical metrics summary.
    #
    # + return - Map of metric values (p50, p90, p99, max, mean, count)
    public isolated function getSummary() returns map<int> {
        lock {
            int p50 = self.getPercentile(50.0d);
            int p90 = self.getPercentile(90.0d);
            int p99 = self.getPercentile(99.0d);
            int mean = self.totalCount > 0 ? (self.sumMicroseconds / self.totalCount) : 0;

            return {
                "count": self.totalCount,
                "p50": p50,
                "p90": p90,
                "p99": p99,
                "max": self.maxMicroseconds,
                "mean": mean
            };
        }
    }
}
