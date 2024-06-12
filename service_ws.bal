// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/websocket;

# In-memory connection registry for streaming WebSocket clients.
public class WebSocketBroadcaster {
    private final map<websocket:Caller> clients = {};

    # Initializes broadcaster.
    public isolated function init() {
    }

    # Registers an active subscriber connection.
    #
    # + caller - WebSocket caller
    public isolated function register(websocket:Caller caller) {
        lock {
            self.clients[caller.getConnectionId()] = caller;
        }
    }

    # Unregisters a closed subscriber connection.
    #
    # + connectionId - Caller connection identifier
    public isolated function unregister(string connectionId) {
        lock {
            if self.clients.hasKey(connectionId) {
                _ = self.clients.remove(connectionId);
            }
        }
    }

    # Broadcasts a JSON financial event to all connected subscriber clients.
    #
    # + event - JSON event payload
    public isolated function broadcast(json event) {
        lock {
            foreach websocket:Caller cl in self.clients {
                error? err = cl->writeMessage(event);
                if err is error {
                    // Client disconnected or socket closed
                }
            }
        }
    }
}

# Global WebSocket broadcaster instance.
final WebSocketBroadcaster broadcaster = new ();

# Configurable WebSocket listening port.
configurable int wsPort = 8991;

# WebSocket real-time event feed service for settlement and risk notifications.
service /ws on new websocket:Listener(wsPort) {

    # Upgrades incoming HTTP connection to WebSocket session.
    #
    # + return - Server service handler or error
    resource function get events() returns websocket:Service|websocket:UpgradeError {
        return new SettlementEventService();
    }
}

# Individual connection session service handler.
service class SettlementEventService {
    *websocket:Service;

    # Triggered when client establishes connection.
    #
    # + caller - WebSocket client caller
    remote function onOpen(websocket:Caller caller) {
        broadcaster.register(caller);
    }

    # Triggered when client closes connection.
    #
    # + caller - WebSocket client caller
    remote function onClose(websocket:Caller caller) {
        broadcaster.unregister(caller.getConnectionId());
    }

    # Triggered when client sends a message or heartbeat ping.
    #
    # + caller - WebSocket client caller
    # + text - Incoming text payload
    # + return - Optional error
    remote function onTextMessage(websocket:Caller caller, string text) returns error? {
        // Echo or acknowledge client heartbeat
        check caller->writeMessage({ "status": "ACK", "echo": text });
    }
}
