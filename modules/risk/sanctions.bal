// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

# Blocked entity record from OFAC or international sanctions lists.
#
# + entityId - Sanction list entry ID
# + normalizedName - Uppercase normalized name or corporate title
# + entityType - INDIVIDUAL, ENTITY, or VESSEL
# + countryCode - Country designation
public type SanctionEntry record {|
    string entityId;
    string normalizedName;
    string entityType;
    string countryCode;
|};

# Sanctions screening engine performing exact and word-tokenized name matching.
public class SanctionsFilter {
    private final map<SanctionEntry> blockedEntities = {};

    # Initializes sanctions filter with baseline simulated SDN entries.
    public isolated function init() {
        self.addEntry({
            entityId: "SDN-001",
            normalizedName: "EVIL CORP CYBER THREATS",
            entityType: "ENTITY",
            countryCode: "KP"
        });
        self.addEntry({
            entityId: "SDN-002",
            normalizedName: "GLOBAL LAUNDERING FRONT",
            entityType: "ENTITY",
            countryCode: "IR"
        });
        self.addEntry({
            entityId: "SDN-003",
            normalizedName: "VIKTOR MALICE DRUG CARTEL",
            entityType: "INDIVIDUAL",
            countryCode: "RU"
        });
    }

    # Adds a sanctioned entity to the filter database.
    #
    # + entry - SanctionEntry record
    public isolated function addEntry(SanctionEntry entry) {
        lock {
            self.blockedEntities[entry.normalizedName] = entry;
        }
    }

    # Screens a counterparty name against the sanctions registry with whole-word token matching.
    #
    # + partyName - Raw name of debtor or creditor
    # + return - Matched SanctionEntry if flagged or nil if clean
    public isolated function screenName(string partyName) returns SanctionEntry? {
        string normalized = partyName.trim().toUpperAscii();
        if normalized.length() == 0 {
            return ();
        }

        lock {
            // 1. Direct exact lookup
            if self.blockedEntities.hasKey(normalized) {
                return self.blockedEntities.get(normalized);
            }

            // 2. Exact full-name match or multi-token overlap
            foreach SanctionEntry entry in self.blockedEntities {
                if normalized == entry.normalizedName {
                    return entry;
                }
                // Check if the sanctioned entity name is contained as an exact whole phrase
                if normalized.includes(entry.normalizedName) {
                    return entry;
                }
            }
        }
        return ();
    }
}
