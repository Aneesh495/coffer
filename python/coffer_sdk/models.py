"""
Data models and enumeration schemas for the Coffer payment network.
"""

from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Dict, List, Optional, Any


class Currency(str, Enum):
    USD = "USD"
    EUR = "EUR"
    GBP = "GBP"
    CHF = "CHF"
    JPY = "JPY"
    CAD = "CAD"
    AUD = "AUD"
    SGD = "SGD"


class PaymentRail(str, Enum):
    FEDNOW = "FEDNOW"
    SEPA_INSTANT = "SEPA_INSTANT"
    RTP = "RTP"
    ACH = "ACH"
    SWIFT = "SWIFT"
    INTERNAL = "INTERNAL"


class PaymentState(str, Enum):
    INITIATED = "INITIATED"
    RISK_ASSESSED = "RISK_ASSESSED"
    QUARANTINED = "QUARANTINED"
    ROUTED = "ROUTED"
    RESERVED = "RESERVED"
    DISPATCHED = "DISPATCHED"
    CLEARED = "CLEARED"
    SETTLED = "SETTLED"
    REJECTED = "REJECTED"
    COMPENSATED = "COMPENSATED"


class AccountCategory(str, Enum):
    ASSET = "ASSET"
    LIABILITY = "LIABILITY"
    EQUITY = "EQUITY"
    REVENUE = "REVENUE"
    EXPENSE = "EXPENSE"
    SETTLEMENT = "SETTLEMENT"
    ESCROW = "ESCROW"


@dataclass
class Institution:
    bic: str
    name: str
    country: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Institution":
        return cls(
            bic=data["bic"],
            name=data["name"],
            country=data["country"]
        )


@dataclass
class Account:
    id: str
    bic: str
    currency: str
    category: str
    balance: str = "0.00"
    held_balance: str = "0.00"
    is_active: bool = True
    metadata: Dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Account":
        return cls(
            id=data["id"],
            bic=data["bic"],
            currency=data["currency"],
            category=data["category"],
            balance=str(data.get("balance", "0.00")),
            held_balance=str(data.get("held_balance", "0.00")),
            is_active=bool(data.get("is_active", True)),
            metadata=dict(data.get("metadata", {}))
        )


@dataclass
class Party:
    account_id: str
    institution: Institution

    def to_dict(self) -> Dict[str, Any]:
        return {
            "account_id": self.account_id,
            "institution": self.institution.to_dict()
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Party":
        return cls(
            account_id=data["account_id"],
            institution=Institution.from_dict(data["institution"])
        )


@dataclass
class TransferRequest:
    idempotency_key: str
    debtor: Party
    creditor: Party
    currency: str
    amount: str
    charge_bearer: str = "SLEV"
    memo: str = ""
    preferred_rail: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        d = {
            "idempotency_key": self.idempotency_key,
            "debtor": self.debtor.to_dict(),
            "creditor": self.creditor.to_dict(),
            "currency": self.currency,
            "amount": self.amount,
            "charge_bearer": self.charge_bearer,
            "memo": self.memo
        }
        if self.preferred_rail:
            d["preferred_rail"] = self.preferred_rail
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TransferRequest":
        return cls(
            idempotency_key=data["idempotency_key"],
            debtor=Party.from_dict(data["debtor"]),
            creditor=Party.from_dict(data["creditor"]),
            currency=data["currency"],
            amount=str(data["amount"]),
            charge_bearer=data.get("charge_bearer", "SLEV"),
            memo=data.get("memo", ""),
            preferred_rail=data.get("preferred_rail")
        )


@dataclass
class TransferResponse:
    payment_id: str
    idempotency_key: str
    state: str
    selected_rail: str
    cleared_at: int
    settlement_reference: str
    message: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TransferResponse":
        return cls(
            payment_id=data["payment_id"],
            idempotency_key=data["idempotency_key"],
            state=data["state"],
            selected_rail=data["selected_rail"],
            cleared_at=int(data.get("cleared_at", 0)),
            settlement_reference=data.get("settlement_reference", ""),
            message=data.get("message", "")
        )


@dataclass
class NettingObligation:
    obligation_id: str
    debtor_bic: str
    creditor_bic: str
    currency: str
    amount: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "NettingObligation":
        return cls(
            obligation_id=data["obligation_id"],
            debtor_bic=data["debtor_bic"],
            creditor_bic=data["creditor_bic"],
            currency=data["currency"],
            amount=str(data["amount"])
        )


@dataclass
class NettingResult:
    cycle_id: str
    total_gross_obligations: int
    gross_volume: str
    net_settlement_volume: str
    liquidity_savings_ratio: float
    is_balanced: bool

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "NettingResult":
        return cls(
            cycle_id=data["cycle_id"],
            total_gross_obligations=int(data.get("total_gross_obligations", 0)),
            gross_volume=str(data.get("gross_volume", "0.00")),
            net_settlement_volume=str(data.get("net_settlement_volume", "0.00")),
            liquidity_savings_ratio=float(data.get("liquidity_savings_ratio", 0.0)),
            is_balanced=bool(data.get("is_balanced", False))
        )


@dataclass
class QuarantineCase:
    case_id: str
    intent_id: str
    account_id: str
    rule_name: str
    reason: str
    status: str
    created_at: int
    resolution: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "QuarantineCase":
        return cls(
            case_id=data["case_id"],
            intent_id=data["intent_id"],
            account_id=data["account_id"],
            rule_name=data["rule_name"],
            reason=data["reason"],
            status=data["status"],
            created_at=int(data.get("created_at", 0)),
            resolution=data.get("resolution")
        )
