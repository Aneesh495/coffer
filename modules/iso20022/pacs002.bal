// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# ISO 20022 Payment Status Code.
public enum PaymentStatusCode {
    ACTC = "ACTC", // Accepted Technical Validation
    ACCP = "ACCP", // Accepted Customer Profile
    ACSC = "ACSC", // Accepted Settlement Completed
    RJCT = "RJCT", // Rejected
    PDNG = "PDNG"  // Pending
}

# Structured representation of a pacs.002.001.12 Payment Status Report.
#
# + messageId - Status report message UUID
# + creationDateTime - Generation timestamp in ISO 8601 format
# + originalMessageId - Original pacs.008 MsgId
# + originalEndToEndId - Original EndToEndId reference
# + originalUetr - Original UETR reference
# + statusCode - High level status code (ACSC, RJCT, etc.)
# + reasonCode - ISO external reason code (e.g. AC04, AM04, NARR)
# + additionalInformation - Detailed explanation of status or rejection reason
public type Pacs002Message record {|
    string messageId;
    string creationDateTime;
    string originalMessageId;
    string originalEndToEndId;
    string originalUetr;
    PaymentStatusCode statusCode;
    string? reasonCode = ();
    string? additionalInformation = ();
|};

# Serializes a Pacs002Message into an ISO 20022 XML document.
#
# + msg - Structured pacs.002 record
# + return - XML document adhering to pacs.002.001.12 schema
public isolated function serializePacs002Xml(Pacs002Message msg) returns xml {
    string statusStr = msg.statusCode.toString();
    xml doc = xml `<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.12">
        <FIToFIPmtStsRpt>
            <GrpHdr>
                <MsgId>${msg.messageId}</MsgId>
                <CreDtTm>${msg.creationDateTime}</CreDtTm>
            </GrpHdr>
            <OrgnlGrpInfAndSts>
                <OrgnlMsgId>${msg.originalMessageId}</OrgnlMsgId>
                <OrgnlMsgNmId>pacs.008.001.10</OrgnlMsgNmId>
            </OrgnlGrpInfAndSts>
            <TxInfAndSts>
                <StsId>STS_${msg.messageId}</StsId>
                <OrgnlEndToEndId>${msg.originalEndToEndId}</OrgnlEndToEndId>
                <OrgnlUETR>${msg.originalUetr}</OrgnlUETR>
                <TxSts>${statusStr}</TxSts>
            </TxInfAndSts>
        </FIToFIPmtStsRpt>
    </Document>`;
    return doc;
}

# Maps internal transaction status to an ISO 20022 payment status code.
#
# + status - Internal TransactionStatus enum
# + return - Corresponding PaymentStatusCode
public isolated function mapStatusToIsoCode(types:TransactionStatus status) returns PaymentStatusCode {
    match status {
        types:SETTLED => {
            return ACSC;
        }
        types:ROUTED => {
            return ACTC;
        }
        types:RESERVED => {
            return ACCP;
        }
        types:DISPATCHED => {
            return PDNG;
        }
        types:FAILED => {
            return RJCT;
        }
        types:QUARANTINED => {
            return PDNG;
        }
        types:COMPENSATED => {
            return RJCT;
        }
        _ => {
            return PDNG;
        }
    }
}
