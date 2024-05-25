// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Master real-time risk assessment, compliance, and fraud prevention engine.
public class RiskEngine {
    private final SanctionsFilter sanctions = new ();
    private final QuarantineStore quarantine = new ();
    private final map<AccountVelocityTracker> velocityTrackers = {};

    # Initializes risk engine with default rule thresholds.
    public function init() {
    }

    # Assesses a transfer intent against real-time fraud rules and sanctions.
    #
    # + intent - Incoming customer payment intent
    # + nowEpochNs - Assessment timestamp in nanoseconds
    # + return - Tuple of [RiskScore (0-100), RiskDecision, RiskTriggers array]
    public isolated function evaluate(types:TransferIntent intent, int nowEpochNs) returns [int, types:RiskDecision, string[]] {
        int score = 0;
        string[] triggers = [];

        // 1. Sanctions Screening
        SanctionEntry? sDebtor = self.sanctions.screenName(intent.debtor.name);
        SanctionEntry? sCreditor = self.sanctions.screenName(intent.creditor.name);
        if sDebtor is SanctionEntry || sCreditor is SanctionEntry {
            string matchedName = sDebtor is SanctionEntry ? intent.debtor.name : intent.creditor.name;
            triggers.push("SANCTION_MATCH: " + matchedName);
            score = 100;
            return [100, types:REJECTED, triggers];
        }

        // 2. Velocity Tracking (1 hour window)
        string debtorId = intent.debtor.id;
        AccountVelocityTracker tracker = self.getOrCreateTracker(debtorId);
        tracker.recordEvent(intent.amount, nowEpochNs);

        // Window: 1 hour in nanoseconds
        int oneHourNs = 3600000000000;
        var [hourlyVol, hourlyCount] = tracker.getVelocityInWindow(oneHourNs, nowEpochNs);

        if hourlyCount > 20 {
            score = score + 35;
            triggers.push("HIGH_VELOCITY: " + hourlyCount.toString() + " txs in last hour");
        }
        if hourlyVol > 50000.0d {
            score = score + 30;
            triggers.push("UNUSUAL_VOLUME: " + hourlyVol.toString() + " transferred in last hour");
        }

        // 3. Structuring / Smurfing Detection (US Bank Secrecy Act sub-$10,000 bursts)
        fixedpoint:ScaledDecimal|error parsedAmt = fixedpoint:fromString(intent.amount);
        if parsedAmt is fixedpoint:ScaledDecimal {
            decimal val = parsedAmt.value;
            if val >= 9000.0d && val < 10000.0d {
                if hourlyCount >= 2 {
                    score = score + 45;
                    triggers.push("STRUCTURING_DETECTED: repeated payments just below reporting threshold");
                }
            }
        }

        // 4. Decision Thresholds
        types:RiskDecision decision = types:APPROVED;
        if score >= 90 {
            decision = types:REJECTED;
        } else if score >= 70 {
            decision = types:QUARANTINED;
            self.quarantine.add({
                transactionId: intent.id,
                intent: intent,
                riskScore: score,
                triggers: triggers,
                quarantinedAtEpochNs: nowEpochNs,
                status: "PENDING_REVIEW"
            });
        } else if score >= 30 {
            decision = types:FLAGGED;
        }

        return [score, decision, triggers];
    }

    # Retrieves or creates a velocity tracker for a debtor identity.
    #
    # + identity - Counterparty account or user ID
    # + return - AccountVelocityTracker instance
    private isolated function getOrCreateTracker(string identity) returns AccountVelocityTracker {
        lock {
            if self.velocityTrackers.hasKey(identity) {
                return self.velocityTrackers.get(identity);
            }
            AccountVelocityTracker t = new ();
            self.velocityTrackers[identity] = t;
            return t;
        }
    }

    # Exposes quarantine store for inspection and administrative action.
    #
    # + return - QuarantineStore reference
    public isolated function getQuarantineStore() returns QuarantineStore {
        return self.quarantine;
    }
}
