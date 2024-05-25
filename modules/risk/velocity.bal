// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.fixedpoint;

# Individual historical payment event recorded in a sliding time window.
#
# + amount - Event amount
# + timestampEpochNs - Nanosecond epoch timestamp
public type VelocityEvent record {|
    decimal amount;
    int timestampEpochNs;
|};

# Sliding-window velocity tracker for a single identity or account.
public class AccountVelocityTracker {
    private VelocityEvent[] events = [];

    # Initializes empty velocity tracker.
    public isolated function init() {
    }

    # Records a new transaction event for the account.
    #
    # + amountStr - Decimal amount string
    # + timestampEpochNs - Event timestamp in nanoseconds
    public isolated function recordEvent(string amountStr, int timestampEpochNs) {
        fixedpoint:ScaledDecimal|error parsed = fixedpoint:fromString(amountStr);
        decimal amt = parsed is fixedpoint:ScaledDecimal ? parsed.value : 0.0d;
        lock {
            self.events.push({
                amount: amt,
                timestampEpochNs: timestampEpochNs
            });
        }
    }

    # Calculates aggregate volume and event count within a sliding window.
    #
    # + windowDurationNs - Rolling window duration in nanoseconds (e.g. 3600_000_000_000 for 1h)
    # + nowEpochNs - Current epoch timestamp
    # + return - Tuple of [totalVolumeDecimal, eventCount]
    public isolated function getVelocityInWindow(int windowDurationNs, int nowEpochNs) returns [decimal, int] {
        int windowStart = nowEpochNs - windowDurationNs;
        decimal totalVol = 0.0d;
        int count = 0;

        lock {
            VelocityEvent[] retained = [];
            foreach VelocityEvent ev in self.events {
                if ev.timestampEpochNs >= windowStart {
                    totalVol = totalVol + ev.amount;
                    count = count + 1;
                    retained.push(ev);
                }
            }
            // Compact historical events older than current window
            self.events = retained;
        }

        return [totalVol, count];
    }
}
