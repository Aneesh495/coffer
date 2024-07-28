"""
Unit test suite for ISO 20022 XML parsing and validation helpers.
"""

import unittest
from coffer_sdk.iso_helpers import Iso20022Helper


SAMPLE_PACS008 = """<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
    <FIToFICstmrCdtTrf>
        <GrpHdr>
            <MsgId>MSG-2026-0001</MsgId>
            <CreDtTm>2026-11-02T12:00:00Z</CreDtTm>
            <NbOfTxs>1</NbOfTxs>
            <InstgAgt><FinInstnId><BICFI>CHASUS33XXX</BICFI></FinInstnId></InstgAgt>
            <InstdAgt><FinInstnId><BICFI>BOFAUS3NXXX</BICFI></FinInstnId></InstdAgt>
        </GrpHdr>
        <CdtTrfTxInf>
            <PmtId>
                <EndToEndId>E2E-9999</EndToEndId>
                <TxId>TX-8888</TxId>
            </PmtId>
            <IntrBkSttlmAmt Ccy="USD">50000.00</IntrBkSttlmAmt>
            <InstdAmt Ccy="USD">50000.00</InstdAmt>
            <Dbtr><Nm>Acme Global Inc</Nm></Dbtr>
            <DbtrAcct><Id><Othr><Id>ACT-100</Id></Othr></Id></DbtrAcct>
            <DbtrAgt><FinInstnId><BICFI>CHASUS33XXX</BICFI></FinInstnId></DbtrAgt>
            <Cdtr><Nm>Starlight Retail LLC</Nm></Cdtr>
            <CdtrAcct><Id><Othr><Id>ACT-200</Id></Othr></Id></CdtrAcct>
            <CdtrAgt><FinInstnId><BICFI>BOFAUS3NXXX</BICFI></FinInstnId></CdtrAgt>
        </CdtTrfTxInf>
    </FIToFICstmrCdtTrf>
</Document>"""

SAMPLE_PACS002 = """<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.12">
    <FIToFIPmtStsRpt>
        <GrpHdr>
            <MsgId>MSG-STAT-001</MsgId>
            <CreDtTm>2026-11-02T12:01:00Z</CreDtTm>
        </GrpHdr>
        <TxInfAndSts>
            <OrgnlMsgId>MSG-2026-0001</OrgnlMsgId>
            <OrgnlTxId>TX-8888</OrgnlTxId>
            <TxSts>ACCP</TxSts>
            <StsRsnInf>
                <Rsn><Cd>ACTC</Cd></Rsn>
                <AddtlInf>Accepted technical validation</AddtlInf>
            </StsRsnInf>
        </TxInfAndSts>
    </FIToFIPmtStsRpt>
</Document>"""


class TestIso20022Helper(unittest.TestCase):

    def test_parse_pacs008(self):
        res = Iso20022Helper.parse_pacs008(SAMPLE_PACS008)
        self.assertEqual(res["message_id"], "MSG-2026-0001")
        self.assertEqual(res["transaction_id"], "TX-8888")
        self.assertEqual(res["end_to_end_id"], "E2E-9999")
        self.assertEqual(res["instructed_amount"], "50000.00")
        self.assertEqual(res["debtor_name"], "Acme Global Inc")
        self.assertEqual(res["debtor_account"], "ACT-100")
        self.assertEqual(res["creditor_name"], "Starlight Retail LLC")

    def test_validate_pacs008_structure(self):
        self.assertTrue(Iso20022Helper.validate_pacs008_structure(SAMPLE_PACS008))
        invalid_xml = "<Document><UnknownRoot /></Document>"
        self.assertFalse(Iso20022Helper.validate_pacs008_structure(invalid_xml))

    def test_parse_pacs002(self):
        res = Iso20022Helper.parse_pacs002(SAMPLE_PACS002)
        self.assertEqual(res["message_id"], "MSG-STAT-001")
        self.assertEqual(res["original_message_id"], "MSG-2026-0001")
        self.assertEqual(res["original_transaction_id"], "TX-8888")
        self.assertEqual(res["transaction_status"], "ACCP")
        self.assertEqual(res["reason_code"], "ACTC")


if __name__ == "__main__":
    unittest.main()
