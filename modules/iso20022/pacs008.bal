// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;
import aneeshkrishna/coffer.fixedpoint;

# Canonical internal structure representing a pacs.008.001.10 customer credit transfer.
#
# + messageId - Business message identification
# + creationDateTime - Creation timestamp in ISO 8601 UTC format
# + settlementMethod - Clearing settlement method (CLRG, INDA, etc.)
# + clearingSystem - Clearing channel (FEDNOW, SEPA, RTP)
# + endToEndId - Unique end to end transaction identifier
# + instructionId - Sending bank internal instruction ID
# + uetr - Unique End-to-end Transaction Reference (RFC 4122 UUID)
# + amount - Scaled transaction amount
# + currency - ISO 4217 currency designation
# + debtorName - Originating debtor name
# + debtorIban - Originator IBAN or account identifier
# + debtorBic - Originator bank BIC
# + creditorName - Beneficiary creditor name
# + creditorIban - Beneficiary IBAN or account identifier
# + creditorBic - Beneficiary bank BIC
# + remittanceInformation - Unstructured narrative payment description
public type Pacs008Message record {|
    string messageId;
    string creationDateTime;
    string settlementMethod;
    string clearingSystem;
    string endToEndId;
    string instructionId;
    string uetr;
    string amount;
    types:Currency currency;
    string debtorName;
    string debtorIban;
    string debtorBic;
    string creditorName;
    string creditorIban;
    string creditorBic;
    string remittanceInformation;
|};

# Serializes an internal Pacs008Message into ISO 20022 XML document representation.
#
# + msg - Structured pacs.008 record
# + return - XML document adhering to pacs.008.001.10 schema
public isolated function serializePacs008Xml(Pacs008Message msg) returns xml {
    string settMethod = msg.settlementMethod.length() == 0 ? "CLRG" : msg.settlementMethod;
    string ccyStr = msg.currency.toString();
    xml doc = xml `<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
        <FIToFICstmrCdtTrf>
            <GrpHdr>
                <MsgId>${msg.messageId}</MsgId>
                <CreDtTm>${msg.creationDateTime}</CreDtTm>
                <NbOfTxs>1</NbOfTxs>
                <SttlmInf>
                    <SttlmMtd>${settMethod}</SttlmMtd>
                    <ClrSys>
                        <Prtry>${msg.clearingSystem}</Prtry>
                    </ClrSys>
                </SttlmInf>
            </GrpHdr>
            <CdtTrfTxInf>
                <PmtId>
                    <InstrId>${msg.instructionId}</InstrId>
                    <EndToEndId>${msg.endToEndId}</EndToEndId>
                    <UETR>${msg.uetr}</UETR>
                </PmtId>
                <IntrBkSttlmAmt Ccy="${ccyStr}">${msg.amount}</IntrBkSttlmAmt>
                <Dbtr>
                    <Nm>${msg.debtorName}</Nm>
                </Dbtr>
                <DbtrAcct>
                    <Id>
                        <Othr>
                            <Id>${msg.debtorIban}</Id>
                        </Othr>
                    </Id>
                </DbtrAcct>
                <DbtrAgt>
                    <FinInstnId>
                        <BICFI>${msg.debtorBic}</BICFI>
                    </FinInstnId>
                </DbtrAgt>
                <CdtrAgt>
                    <FinInstnId>
                        <BICFI>${msg.creditorBic}</BICFI>
                    </FinInstnId>
                </CdtrAgt>
                <Cdtr>
                    <Nm>${msg.creditorName}</Nm>
                </Cdtr>
                <CdtrAcct>
                    <Id>
                        <Othr>
                            <Id>${msg.creditorIban}</Id>
                        </Othr>
                    </Id>
                </CdtrAcct>
                <RmtInf>
                    <Ustrd>${msg.remittanceInformation}</Ustrd>
                </RmtInf>
            </CdtTrfTxInf>
        </FIToFICstmrCdtTrf>
    </Document>`;
    return doc;
}

# Constructs a Pacs008Message from a canonical TransferIntent.
#
# + intent - Customer transfer intent
# + messageId - Generated ISO message ID
# + isoDateTime - Timestamp string
# + rail - Active payment rail
# + return - Initialized Pacs008Message
public isolated function fromTransferIntent(
    types:TransferIntent intent,
    string messageId,
    string isoDateTime,
    types:PaymentRail rail
) returns Pacs008Message {
    return {
        messageId: messageId,
        creationDateTime: isoDateTime,
        settlementMethod: "CLRG",
        clearingSystem: rail.toString(),
        endToEndId: intent.endToEndId,
        instructionId: "INSTR_" + intent.id,
        uetr: intent.id,
        amount: intent.amount,
        currency: intent.currency,
        debtorName: intent.debtor.name,
        debtorIban: intent.debtor.accountIdentifier,
        debtorBic: intent.debtor.institution.bic,
        creditorName: intent.creditor.name,
        creditorIban: intent.creditor.accountIdentifier,
        creditorBic: intent.creditor.institution.bic,
        remittanceInformation: intent.remittanceInformation
    };
}

# Validates semantic compliance of a Pacs008Message before wire dispatch.
#
# + msg - Target pacs.008 record
# + return - Nil or ISOValidationError on non-conforming fields
public isolated function validatePacs008(Pacs008Message msg) returns types:ISOValidationError? {
    if msg.messageId.length() == 0 || msg.messageId.length() > 35 {
        return error types:ISOValidationError("Invalid MsgId: must be between 1 and 35 characters");
    }
    if msg.endToEndId.length() == 0 || msg.endToEndId.length() > 35 {
        return error types:ISOValidationError("Invalid EndToEndId: must be between 1 and 35 characters");
    }
    if msg.debtorBic.length() != 8 && msg.debtorBic.length() != 11 {
        return error types:ISOValidationError("Invalid Debtor BIC: must be 8 or 11 characters, found: " + msg.debtorBic);
    }
    if msg.creditorBic.length() != 8 && msg.creditorBic.length() != 11 {
        return error types:ISOValidationError("Invalid Creditor BIC: must be 8 or 11 characters, found: " + msg.creditorBic);
    }
    fixedpoint:ScaledDecimal|types:FixedPointArithmeticError amt = fixedpoint:fromString(msg.amount);
    if amt is types:FixedPointArithmeticError || !fixedpoint:isPositive(amt) {
        return error types:ISOValidationError("Invalid transfer amount: must be positive numerical, found: " + msg.amount);
    }
}
