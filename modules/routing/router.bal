// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Thread-safe multi-rail routing coordinator and circuit breaker manager.
public class PaymentRouter {
    private final map<types:RailHealth> registry = {};

    # Initializes router with standard production rails.
    public function init() {
        self.registerRail(createDefaultRailHealth(types:FEDNOW));
        self.registerRail(createDefaultRailHealth(types:SEPA_INSTANT));
        self.registerRail(createDefaultRailHealth(types:RTP));
        self.registerRail(createDefaultRailHealth(types:ACH));
        self.registerRail(createDefaultRailHealth(types:SWIFT));
        self.registerRail(createDefaultRailHealth(types:INTERNAL));
    }

    # Registers or updates health configuration for a payment rail.
    #
    # + health - Rail health configuration
    public isolated function registerRail(types:RailHealth health) {
        lock {
            self.registry[health.rail.toString()] = health;
        }
    }

    # Selects optimal route for transfer intent based on live network topology.
    #
    # + intent - Customer transfer intent
    # + return - RoutingDecision or RailUnavailableError
    public isolated function route(types:TransferIntent intent) returns types:RoutingDecision|types:RailUnavailableError {
        lock {
            return selectOptimalRail(intent, self.registry);
        }
    }

    # Records successful dispatch on a rail, resetting consecutive error counts.
    #
    # + rail - Target rail
    public isolated function recordSuccess(types:PaymentRail rail) {
        lock {
            string key = rail.toString();
            if self.registry.hasKey(key) {
                types:RailHealth h = self.registry.get(key);
                h.consecutiveErrors = 0;
                if h.circuitOpen {
                    h.circuitOpen = false;
                }
                self.registry[key] = h;
            }
        }
    }

    # Records a dispatch failure, tripping circuit breaker if threshold is exceeded.
    #
    # + rail - Target rail
    # + nowEpochMs - Current timestamp in milliseconds
    public isolated function recordFailure(types:PaymentRail rail, int nowEpochMs) {
        lock {
            string key = rail.toString();
            if self.registry.hasKey(key) {
                types:RailHealth h = self.registry.get(key);
                h.failureCount = h.failureCount + 1;
                h.consecutiveErrors = h.consecutiveErrors + 1;
                if h.consecutiveErrors >= h.circuitTripThreshold {
                    h.circuitOpen = true;
                    h.circuitHalfOpenEpochMs = nowEpochMs + 30000; // 30s cooldown
                }
                self.registry[key] = h;
            }
        }
    }

    # Retrieves health snapshot for a rail.
    #
    # + rail - Payment rail to query
    # + return - RailHealth snapshot or error
    public isolated function getRailHealth(types:PaymentRail rail) returns types:RailHealth|error {
        lock {
            string key = rail.toString();
            if !self.registry.hasKey(key) {
                return error("Rail not found in registry: " + key);
            }
            return self.registry.get(key);
        }
    }
}
