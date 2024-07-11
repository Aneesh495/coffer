"""
Authentication and cryptographic signature helpers for Coffer API interactions.
"""

import hmac
import hashlib
import time
from typing import Dict


class HmacAuthenticator:
    """
    Generates and verifies cryptographic signatures for API requests
    using HMAC-SHA256 with timestamp replay protection.
    """

    def __init__(self, api_key: str, secret_key: str):
        self.api_key = api_key
        self.secret_key = secret_key.encode("utf-8")

    def sign_request(self, method: str, path: str, body: str = "") -> Dict[str, str]:
        """
        Signs an HTTP request with X-Coffer-Key, X-Coffer-Timestamp, and X-Coffer-Signature.
        """
        timestamp = str(int(time.time()))
        canonical_string = f"{method.upper()}\n{path}\n{timestamp}\n{body}"
        signature = hmac.new(
            self.secret_key,
            canonical_string.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        return {
            "X-Coffer-Key": self.api_key,
            "X-Coffer-Timestamp": timestamp,
            "X-Coffer-Signature": signature
        }

    def verify_signature(
        self,
        method: str,
        path: str,
        timestamp: str,
        body: str,
        signature: str,
        max_drift_seconds: int = 300
    ) -> bool:
        """
        Validates timestamp drift and HMAC signature match.
        """
        now = int(time.time())
        try:
            req_time = int(timestamp)
        except ValueError:
            return False

        if abs(now - req_time) > max_drift_seconds:
            return False

        canonical_string = f"{method.upper()}\n{path}\n{timestamp}\n{body}"
        expected_sig = hmac.new(
            self.secret_key,
            canonical_string.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        return hmac.compare_digest(expected_sig, signature)
