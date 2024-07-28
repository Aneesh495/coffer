"""
Unit test suite for Coffer Python SDK core models, authentication, and client.
"""

import unittest
import time
from coffer_sdk.models import (
    Institution,
    Party,
    Account,
    AccountCategory,
    Currency,
    PaymentRail,
    TransferRequest,
    TransferResponse,
    NettingObligation,
    NettingResult,
)
from coffer_sdk.auth import HmacAuthenticator
from coffer_sdk.client import CofferClient, CofferApiError


class TestCofferSdkModels(unittest.TestCase):

    def test_institution_serialization(self):
        inst = Institution(bic="CHASUS33XXX", name="JPMorgan Chase", country="US")
        d = inst.to_dict()
        self.assertEqual(d["bic"], "CHASUS33XXX")
        self.assertEqual(d["name"], "JPMorgan Chase")
        self.assertEqual(d["country"], "US")

        recovered = Institution.from_dict(d)
        self.assertEqual(recovered.bic, inst.bic)
        self.assertEqual(recovered.name, inst.name)
        self.assertEqual(recovered.country, inst.country)

    def test_account_serialization(self):
        acct = Account(
            id="ACT-001",
            bic="CHASUS33XXX",
            currency="USD",
            category=AccountCategory.SETTLEMENT.value,
            balance="1500000.50",
            held_balance="5000.00"
        )
        d = acct.to_dict()
        self.assertEqual(d["balance"], "1500000.50")
        recovered = Account.from_dict(d)
        self.assertEqual(recovered.id, "ACT-001")
        self.assertEqual(recovered.held_balance, "5000.00")

    def test_transfer_request_serialization(self):
        debtor_inst = Institution(bic="CHASUS33XXX", name="JPMorgan", country="US")
        creditor_inst = Institution(bic="BOFAUS3NXXX", name="Bank of America", country="US")
        req = TransferRequest(
            idempotency_key="IDEMP-12345",
            debtor=Party(account_id="ACT-DEBTOR", institution=debtor_inst),
            creditor=Party(account_id="ACT-CREDITOR", institution=creditor_inst),
            currency=Currency.USD.value,
            amount="45000.00",
            charge_bearer="SLEV",
            memo="Treasury wire"
        )
        d = req.to_dict()
        self.assertEqual(d["idempotency_key"], "IDEMP-12345")
        self.assertEqual(d["amount"], "45000.00")

        recovered = TransferRequest.from_dict(d)
        self.assertEqual(recovered.idempotency_key, req.idempotency_key)
        self.assertEqual(recovered.debtor.account_id, "ACT-DEBTOR")
        self.assertEqual(recovered.creditor.institution.bic, "BOFAUS3NXXX")


class TestHmacAuthentication(unittest.TestCase):

    def setUp(self):
        self.auth = HmacAuthenticator(api_key="KEY-789", secret_key="SUPER-SECRET-COFFER-KEY")

    def test_sign_and_verify_valid_request(self):
        method = "POST"
        path = "/api/v1/transfers"
        body = '{"amount":"100.00"}'
        headers = self.auth.sign_request(method, path, body)

        self.assertIn("X-Coffer-Key", headers)
        self.assertIn("X-Coffer-Timestamp", headers)
        self.assertIn("X-Coffer-Signature", headers)

        is_valid = self.auth.verify_signature(
            method=method,
            path=path,
            timestamp=headers["X-Coffer-Timestamp"],
            body=body,
            signature=headers["X-Coffer-Signature"]
        )
        self.assertTrue(is_valid)

    def test_signature_tamper_detection(self):
        method = "POST"
        path = "/api/v1/transfers"
        body = '{"amount":"100.00"}'
        headers = self.auth.sign_request(method, path, body)

        tampered_body = '{"amount":"999999.00"}'
        is_valid = self.auth.verify_signature(
            method=method,
            path=path,
            timestamp=headers["X-Coffer-Timestamp"],
            body=tampered_body,
            signature=headers["X-Coffer-Signature"]
        )
        self.assertFalse(is_valid)

    def test_timestamp_drift_replay_rejection(self):
        method = "GET"
        path = "/api/v1/accounts/ACT-001"
        stale_timestamp = str(int(time.time()) - 400) # Exceeds 300s window

        is_valid = self.auth.verify_signature(
            method=method,
            path=path,
            timestamp=stale_timestamp,
            body="",
            signature="mock-sig",
            max_drift_seconds=300
        )
        self.assertFalse(is_valid)


if __name__ == "__main__":
    unittest.main()
