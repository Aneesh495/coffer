"""
Coffer HTTP REST API Client implementations (synchronous and asynchronous).
"""

import json
import urllib.request
import urllib.error
import asyncio
from typing import Dict, Any, Optional, List
from .models import (
    Account,
    TransferRequest,
    TransferResponse,
    NettingObligation,
    NettingResult,
    QuarantineCase,
)
from .auth import HmacAuthenticator


class CofferApiError(Exception):
    """Exception raised when Coffer API returns an error response."""
    def __init__(self, status_code: int, message: str, payload: Optional[Dict[str, Any]] = None):
        super().__init__(f"Coffer API Error [{status_code}]: {message}")
        self.status_code = status_code
        self.message = message
        self.payload = payload or {}


class CofferClient:
    """
    Synchronous client for communicating with the Coffer Payment Orchestrator.
    Built on standard library urllib to eliminate third-party dependencies.
    """

    def __init__(
        self,
        base_url: str = "http://127.0.0.1:8990",
        api_key: Optional[str] = None,
        secret_key: Optional[str] = None,
        timeout: float = 10.0
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.auth = HmacAuthenticator(api_key, secret_key) if api_key and secret_key else None

    def _request(
        self,
        method: str,
        path: str,
        payload: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        body_bytes = b""
        req_headers = {
            "User-Agent": "Coffer-Python-SDK/0.1.0",
            "Accept": "application/json"
        }

        if headers:
            req_headers.update(headers)

        if payload is not None:
            body_str = json.dumps(payload)
            body_bytes = body_str.encode("utf-8")
            req_headers["Content-Type"] = "application/json"
        else:
            body_str = ""

        if self.auth:
            sig_headers = self.auth.sign_request(method, path, body_str)
            req_headers.update(sig_headers)

        req = urllib.request.Request(url, data=body_bytes if method != "GET" else None, method=method)
        for k, v in req_headers.items():
            req.add_header(k, v)

        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                resp_bytes = resp.read()
                if not resp_bytes:
                    return {}
                return json.loads(resp_bytes.decode("utf-8"))
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            try:
                err_json = json.loads(err_body)
                msg = err_json.get("message", err_body)
            except Exception:
                err_json = {"raw": err_body}
                msg = err_body
            raise CofferApiError(e.code, msg, err_json) from e
        except urllib.error.URLError as e:
            raise CofferApiError(0, f"Connection failed: {str(e.reason)}") from e

    def health(self) -> Dict[str, Any]:
        """Queries gateway health status."""
        return self._request("GET", "/health")

    def register_account(self, account: Account) -> Account:
        """Registers a new account in the double-entry ledger."""
        res = self._request("POST", "/api/v1/accounts", account.to_dict())
        return Account.from_dict(res)

    def get_account(self, account_id: str) -> Account:
        """Fetches account state and real-time ledger balance."""
        res = self._request("GET", f"/api/v1/accounts/{account_id}")
        return Account.from_dict(res)

    def execute_transfer(self, transfer: TransferRequest) -> TransferResponse:
        """Submits an end-to-end payment intent for clearance."""
        headers = {"X-Idempotency-Key": transfer.idempotency_key}
        res = self._request("POST", "/api/v1/transfers", transfer.to_dict(), headers=headers)
        return TransferResponse.from_dict(res)

    def review_quarantine(self, case_id: str, decision: str, notes: str = "") -> Dict[str, Any]:
        """Reviews and resolves a quarantined payment intent."""
        payload = {"decision": decision.upper(), "notes": notes}
        return self._request("POST", f"/api/v1/quarantine/{case_id}/review", payload)

    def execute_netting_cycle(self, obligations: List[NettingObligation]) -> NettingResult:
        """Runs a multilateral netting cycle optimization across obligations."""
        payload = {"obligations": [ob.to_dict() for ob in obligations]}
        res = self._request("POST", "/api/v1/netting/cycles", payload)
        return NettingResult.from_dict(res)

    def get_metrics(self) -> str:
        """Scrapes OpenMetrics / Prometheus telemetry from the gateway."""
        url = f"{self.base_url}/metrics"
        req = urllib.request.Request(url, method="GET")
        req.add_header("User-Agent", "Coffer-Python-SDK/0.1.0")
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return resp.read().decode("utf-8")
        except Exception as e:
            raise CofferApiError(0, f"Metrics scrape failed: {str(e)}") from e


class CofferClientAsync:
    """
    Asynchronous client wrapper providing non-blocking API interactions
    via an asyncio thread pool executor.
    """

    def __init__(
        self,
        base_url: str = "http://127.0.0.1:8990",
        api_key: Optional[str] = None,
        secret_key: Optional[str] = None,
        timeout: float = 10.0
    ):
        self._sync_client = CofferClient(base_url, api_key, secret_key, timeout)

    async def health(self) -> Dict[str, Any]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.health)

    async def register_account(self, account: Account) -> Account:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.register_account, account)

    async def get_account(self, account_id: str) -> Account:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.get_account, account_id)

    async def execute_transfer(self, transfer: TransferRequest) -> TransferResponse:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.execute_transfer, transfer)

    async def review_quarantine(self, case_id: str, decision: str, notes: str = "") -> Dict[str, Any]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.review_quarantine, case_id, decision, notes)

    async def execute_netting_cycle(self, obligations: List[NettingObligation]) -> NettingResult:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.execute_netting_cycle, obligations)

    async def get_metrics(self) -> str:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._sync_client.get_metrics)
