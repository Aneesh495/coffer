// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Converts an internal TransferIntent into a validated pacs.008 XML message document.
#
# + intent - Transfer intent to serialize
# + messageId - Generated ISO message identifier
# + nowIsoDateTime - ISO 8601 formatted timestamp
# + rail - Active clearing rail
# + return - Serialized XML document or ISOValidationError
public isolated function createPacs008Document(
    types:TransferIntent intent,
    string messageId,
    string nowIsoDateTime,
    types:PaymentRail rail
) returns xml|types:ISOValidationError {
    Pacs008Message msg = fromTransferIntent(intent, messageId, nowIsoDateTime, rail);
    types:ISOValidationError? validation = validatePacs008(msg);
    if validation is types:ISOValidationError {
        return validation;
    }
    return serializePacs008Xml(msg);
}

# Creates a pacs.002 status report XML document from a transaction record.
#
# + tx - Transaction state record
# + messageId - Status report message ID
# + nowIsoDateTime - ISO 8601 formatted timestamp
# + return - Serialized XML document
public isolated function createPacs002Document(
    types:TransactionRecord tx,
    string messageId,
    string nowIsoDateTime
) returns xml {
    PaymentStatusCode code = mapStatusToIsoCode(tx.status);
    Pacs002Message msg = {
        messageId: messageId,
        creationDateTime: nowIsoDateTime,
        originalMessageId: "MSG_" + tx.id,
        originalEndToEndId: tx.endToEndId,
        originalUetr: tx.id,
        statusCode: code,
        reasonCode: tx.status == types:FAILED ? "AM04" : (),
        additionalInformation: tx.failureReason
    };
    return serializePacs002Xml(msg);
}
