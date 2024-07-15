"""
ISO 20022 XML message parsing, serialization, and schema validation helpers.
"""

import xml.etree.ElementTree as ET
from typing import Dict, Any, Optional


class Iso20022Helper:
    """
    Utilities for ISO 20022 XML document serialization, inspection,
    and extraction of core payment attributes.
    """

    @staticmethod
    def parse_pacs008(xml_content: str) -> Dict[str, Any]:
        """
        Parses pacs.008.001.10 customer credit transfer XML payload.
        """
        root = ET.fromstring(xml_content)
        # Handle namespaces if present
        def find_element(elem: ET.Element, tag: str) -> Optional[ET.Element]:
            for child in elem.iter():
                if child.tag.endswith(tag):
                    return child
            return None

        def get_text(elem: Optional[ET.Element]) -> str:
            if elem is None:
                return ""
            if elem.text and elem.text.strip():
                return elem.text.strip()
            for sub in elem.iter():
                if sub is not elem and sub.text and sub.text.strip():
                    return sub.text.strip()
            return ""

        msg_id = get_text(find_element(root, "MsgId"))
        instructing_agent = get_text(find_element(root, "InstgAgt"))
        tx_id = get_text(find_element(root, "TxId"))
        end_to_end_id = get_text(find_element(root, "EndToEndId"))
        instd_amt = get_text(find_element(root, "InstdAmt"))
        debtor_name = get_text(find_element(root, "Dbtr"))
        debtor_acct = get_text(find_element(root, "DbtrAcct"))
        debtor_bic = get_text(find_element(root, "DbtrAgt"))
        creditor_name = get_text(find_element(root, "Cdtr"))
        creditor_bic = get_text(find_element(root, "CdtrAgt"))

        return {
            "message_id": msg_id,
            "instructing_agent": instructing_agent,
            "transaction_id": tx_id,
            "end_to_end_id": end_to_end_id,
            "instructed_amount": instd_amt,
            "debtor_name": debtor_name,
            "debtor_account": debtor_acct,
            "debtor_bic": debtor_bic,
            "creditor_name": creditor_name,
            "creditor_bic": creditor_bic,
        }

    @staticmethod
    def parse_pacs002(xml_content: str) -> Dict[str, Any]:
        """
        Parses pacs.002.001.12 payment status report XML payload.
        """
        root = ET.fromstring(xml_content)
        def find_element(elem: ET.Element, tag: str) -> Optional[ET.Element]:
            for child in elem.iter():
                if child.tag.endswith(tag):
                    return child
            return None

        def get_text(elem: Optional[ET.Element]) -> str:
            if elem is None:
                return ""
            if elem.text and elem.text.strip():
                return elem.text.strip()
            for sub in elem.iter():
                if sub is not elem and sub.text and sub.text.strip():
                    return sub.text.strip()
            return ""

        msg_id = get_text(find_element(root, "MsgId"))
        orig_msg_id = get_text(find_element(root, "OrgnlMsgId"))
        orig_tx_id = get_text(find_element(root, "OrgnlTxId"))
        status = get_text(find_element(root, "TxSts"))
        reason_code = get_text(find_element(root, "Cd"))
        addtl_info = get_text(find_element(root, "AddtlInf"))

        return {
            "message_id": msg_id,
            "original_message_id": orig_msg_id,
            "original_transaction_id": orig_tx_id,
            "transaction_status": status,
            "reason_code": reason_code,
            "additional_info": addtl_info
        }

    @staticmethod
    def validate_pacs008_structure(xml_content: str) -> bool:
        """
        Validates basic structure of pacs.008 message.
        """
        try:
            root = ET.fromstring(xml_content)
            has_fitoficstmr = any(c.tag.endswith("FIToFICstmrCdtTrf") for c in root.iter())
            has_grphdr = any(c.tag.endswith("GrpHdr") for c in root.iter())
            has_txinf = any(c.tag.endswith("CdtTrfTxInf") for c in root.iter())
            return has_fitoficstmr and has_grphdr and has_txinf
        except ET.ParseError:
            return False
