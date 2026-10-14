"""Emit safe Python stage events for Gridline Debug over stderr."""
from __future__ import annotations

import json
import os
import re
import sys

PREFIX = "GRIDLINE_TRACE "
DEBUG_PREFIX = "GRIDLINE_DEBUG "
_SAFE_NAME = re.compile(r"^[A-Za-z0-9_.:-]{1,100}$")
_SAFE_FEATURE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
_SAFE_MESSAGE = re.compile(r"^[A-Za-z0-9 _.-]{1,100}$")
_STATUSES = {"started", "completed", "failed", "skipped"}


def stage(workflow: str, name: str, status: str, error: BaseException | None = None, **counts: int) -> None:
    """Write only fixed stage names, status, exception class, and numeric counts."""
    if os.environ.get("GRIDLINE_DEBUG_TRACE") != "1":
        return
    if not _SAFE_NAME.fullmatch(workflow) or not _SAFE_NAME.fullmatch(name) or status not in _STATUSES:
        return
    row: dict[str, object] = {"workflow": workflow, "stage": name, "status": status}
    if error is not None:
        row["errorType"] = getattr(error, "cause_type", type(error).__name__)
    safe_counts = {key: max(0, int(value)) for key, value in counts.items() if _SAFE_NAME.fullmatch(key)}
    if safe_counts:
        row["counts"] = safe_counts
    sys.stderr.write(PREFIX + json.dumps(row, separators=(",", ":")) + "\n")
    sys.stderr.flush()


def debug_event(
    feature: str,
    message: str,
    *,
    group_name: str | None = None,
    session_id: str | None = None,
    **counts: int,
) -> None:
    """Emit one feature-prefixed, content-free DEBUG event while Debug is open."""
    if os.environ.get("GRIDLINE_DEBUG_TRACE") != "1":
        return
    if not _SAFE_FEATURE.fullmatch(feature) or not _SAFE_MESSAGE.fullmatch(message):
        return
    row: dict[str, object] = {
        "feature": feature,
        "prefix": f"{feature} - {message}",
        "message": message,
    }
    if group_name:
        safe_group = " ".join(group_name.split())[:100]
        if safe_group:
            row["groupName"] = safe_group
    if session_id and _SAFE_NAME.fullmatch(session_id):
        row["session"] = session_id
    safe_counts = {key: max(0, int(value)) for key, value in counts.items() if _SAFE_NAME.fullmatch(key)}
    if safe_counts:
        row["counts"] = safe_counts
    sys.stderr.write(DEBUG_PREFIX + json.dumps(row, separators=(",", ":")) + "\n")
    sys.stderr.flush()
