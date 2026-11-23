"""0.9.12.4 Merge history: content-meta parsing and the in-memory log of merges / unmerges pressed
in this app. IDMC documents no read-merge-history API (only entity-history .../anonymize, p. 78,
which tx-mdm never calls), so history = who contributes what now + this app's own log."""

import threading
from datetime import UTC, datetime

from pydantic import JsonValue

from app.b360data.models import AppEventKind, AppMergeEvent, SourceKey, TrustEntry

_LOCK = threading.Lock()
_EVENTS: list[AppMergeEvent] = []
_KEEP = 500

NO_LOG_NOTE = (
    "IDMC exposes no merge-event log through its API, so this is who contributes what NOW "
    "(content meta, _showContentMeta=true, p. 19; members p. 70; source records p. 80), not a full "
    "event history. Merges / unmerges pressed in THIS app are listed too, from backend memory: "
    "lost when the backend restarts."
)


def add_merge(
    entity: str, business_ids: list[str], survivor: str | None, approval: bool | None
) -> None:
    _add(
        AppMergeEvent(
            at=datetime.now(UTC),
            kind=AppEventKind.MERGE,
            entity=entity,
            business_ids=business_ids,
            surviving_business_id=survivor,
            approval_required=approval,
        )
    )


def add_unmerge(
    entity: str, business_id: str, sources: list[SourceKey], approval: bool | None
) -> None:
    _add(
        AppMergeEvent(
            at=datetime.now(UTC),
            kind=AppEventKind.UNMERGE,
            entity=entity,
            business_ids=[business_id],
            sources=sources,
            approval_required=approval,
        )
    )


def _add(event: AppMergeEvent) -> None:
    with _LOCK:
        _EVENTS.append(event)
        del _EVENTS[:-_KEEP]


def events_for(entity: str, business_id: str) -> list[AppMergeEvent]:
    with _LOCK:
        return [
            e
            for e in _EVENTS
            if e.entity == entity
            and (business_id in e.business_ids or e.surviving_business_id == business_id)
        ]


def clear() -> None:
    with _LOCK:
        _EVENTS.clear()


def _when(raw: JsonValue) -> datetime | None:
    if isinstance(raw, (int, float)) and not isinstance(raw, bool):
        return datetime.fromtimestamp(raw / 1000, tz=UTC)
    if isinstance(raw, str):
        try:
            return datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def _text(raw: JsonValue) -> str | None:
    return str(raw) if isinstance(raw, (str, int)) and not isinstance(raw, bool) else None


def trust_entries(reply: JsonValue) -> list[TrustEntry]:
    """_contentMeta.trust.fieldData[] of a Read Master / Read Source Record reply."""
    if not isinstance(reply, dict):
        return []
    content = reply.get("_contentMeta")
    trust = content.get("trust") if isinstance(content, dict) else None
    data = trust.get("fieldData") if isinstance(trust, dict) else None
    out: list[TrustEntry] = []
    for item in data if isinstance(data, list) else []:
        if not isinstance(item, dict):
            continue
        score = item.get("trustScore")
        override = item.get("manualOverride")
        out.append(
            TrustEntry(
                field_ref=_text(item.get("fieldRef")) or "/",
                source_system=_text(item.get("sourceSystem")),
                source_pkey=_text(item.get("sourcePrimaryKey")),
                trust_rule=_text(item.get("trustRule")),
                trust_score=float(score)
                if isinstance(score, (int, float)) and not isinstance(score, bool)
                else None,
                manual_override=override if isinstance(override, bool) else None,
                last_updated=_when(item.get("lastUpdatedDate") or item.get("sourceLastUpdateDate")),
            )
        )
    return out


def winner_for(field: str, trust: list[TrustEntry]) -> TrustEntry | None:
    """The field's own entry, else the record-wide '/' entry."""
    exact = next((t for t in trust if t.field_ref == field), None)
    return exact or next((t for t in trust if t.field_ref == "/"), None)


def when(raw: JsonValue) -> datetime | None:
    return _when(raw)
