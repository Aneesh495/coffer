# ISO 20022 Messaging Specification and Schema Dictionary

## 1. Scope and Supported Message Catalog

Coffer implements native serialization, parsing, and structural validation for key ISO 20022 XML financial messaging formats:

| Message ID | Message Name | Function in Coffer Architecture |
| :--- | :--- | :--- |
| **pacs.008.001.10** | FIToFICstmrCdtTrf | Outbound payment instruction dispatched to FedNow, SEPA, RTP, or SWIFT |
| **pacs.002.001.12** | FIToFIPmtStsRpt | Inbound clearing acknowledgment and technical status reports |
| **camt.053.001.10** | BkToCstmrStmt | End-of-cycle balance statement and transaction reconciliation ledger |

---

## 2. pacs.008.001.10: Customer Credit Transfer

The `pacs.008` message transfers credit between instructing and instructed financial institutions on behalf of customers.

### Key Field Mapping:

```xml
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
    <FIToFICstmrCdtTrf>
        <GrpHdr>
            <MsgId>MSG-20261102-001</MsgId>
            <CreDtTm>2026-11-02T12:00:00Z</CreDtTm>
            <NbOfTxs>1</NbOfTxs>
            <InstgAgt>
                <FinInstnId><BICFI>CHASUS33XXX</BICFI></FinInstnId>
            </InstgAgt>
            <InstdAgt>
                <FinInstnId><BICFI>BOFAUS3NXXX</BICFI></FinInstnId>
            </InstdAgt>
        </GrpHdr>
        <CdtTrfTxInf>
            <PmtId>
                <EndToEndId>E2E-CHASE-BOFA-001</EndToEndId>
                <TxId>TX-9901</TxId>
            </PmtId>
            <IntrBkSttlmAmt Ccy="USD">15000.00</IntrBkSttlmAmt>
            <InstdAmt Ccy="USD">15000.00</InstdAmt>
            <Dbtr>
                <Nm>Alpha Corp Treasury</Nm>
            </Dbtr>
            <DbtrAcct>
                <Id><Othr><Id>CHK-1001</Id></Othr></Id>
            </DbtrAcct>
            <DbtrAgt>
                <FinInstnId><BICFI>CHASUS33XXX</BICFI></FinInstnId>
            </DbtrAgt>
            <Cdtr>
                <Nm>Omega Holdings LLC</Nm>
            </Cdtr>
            <CdtrAcct>
                <Id><Othr><Id>CHK-2002</Id></Othr></Id>
            </CdtrAcct>
            <CdtrAgt>
                <FinInstnId><BICFI>BOFAUS3NXXX</BICFI></FinInstnId>
            </CdtrAgt>
        </CdtTrfTxInf>
    </FIToFICstmrCdtTrf>
</Document>
```

---

## 3. pacs.002.001.12: Payment Status Report

External payment rails report the clearing fate of a transaction via `pacs.002`:

| Status Code | Meaning | Engine Action |
| :--- | :--- | :--- |
| **ACCP** | Accepted Customer Profile | Positive clearing confirmation. Commits journal batch. |
| **ACTC** | Accepted Technical Validation | Rail acknowledged receipt; awaiting final settlement. |
| **RJCT** | Rejected | Dispatch failed. Triggers automated saga compensation rollback. |
| **PDNG** | Pending | Transaction held for manual inquiry or rail liquidity window. |

---

## 4. camt.053.001.10: Bank-to-Customer Account Statement

At end-of-day or completion of a multilateral netting cycle, Coffer emits `camt.053` reports containing:
- Opening settled balance.
- Itemized debit and credit journal batches.
- Closing settled balance and closing available balance.
- Cryptographic Merkle root verifying batch inclusion.
