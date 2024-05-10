// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Bank-to-Customer Statement line entry for camt.053.
#
# + entryReference - Unique entry sequence reference
# + amount - Amount posted
# + currency - ISO 4217 denomination
# + creditDebitIndicator - CRDT or DBIT
# + bookingDateTime - ISO 8601 posting datetime
# + narrative - Description or remittance note
public type StatementEntry record {|
    string entryReference;
    string amount;
    types:Currency currency;
    string creditDebitIndicator;
    string bookingDateTime;
    string narrative;
|};

# Bank-to-Customer Statement payload representing camt.053.001.10.
#
# + statementId - Unique statement document identifier
# + creationDateTime - Statement generation datetime
# + accountIban - Account number or IBAN
# + accountCurrency - Denomination of statement account
# + openingBalance - Opening settled balance
# + closingBalance - Closing settled balance
# + entries - Array of posted transactions during reporting window
public type Camt053Statement record {|
    string statementId;
    string creationDateTime;
    string accountIban;
    types:Currency accountCurrency;
    string openingBalance;
    string closingBalance;
    StatementEntry[] entries;
|};

# Serializes a Camt053Statement into ISO 20022 XML representation.
#
# + stmt - Structured statement record
# + return - XML document conforming to camt.053.001.10 schema
public isolated function serializeCamt053Xml(Camt053Statement stmt) returns xml {
    string ccyStr = stmt.accountCurrency.toString();
    xml doc = xml `<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.10">
        <BkToCstmrStmt>
            <GrpHdr>
                <MsgId>${stmt.statementId}</MsgId>
                <CreDtTm>${stmt.creationDateTime}</CreDtTm>
            </GrpHdr>
            <Stmt>
                <Id>${stmt.statementId}</Id>
                <Acct>
                    <Id>
                        <Othr>
                            <Id>${stmt.accountIban}</Id>
                        </Othr>
                    </Id>
                    <Ccy>${ccyStr}</Ccy>
                </Acct>
                <Bal>
                    <Tp>
                        <CdOrPrtry>
                            <Cd>OPBD</Cd>
                        </CdOrPrtry>
                    </Tp>
                    <Amt Ccy="${ccyStr}">${stmt.openingBalance}</Amt>
                </Bal>
                <Bal>
                    <Tp>
                        <CdOrPrtry>
                            <Cd>CLBD</Cd>
                        </CdOrPrtry>
                    </Tp>
                    <Amt Ccy="${ccyStr}">${stmt.closingBalance}</Amt>
                </Bal>
            </Stmt>
        </BkToCstmrStmt>
    </Document>`;
    return doc;
}
