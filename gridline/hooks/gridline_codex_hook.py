#!/usr/bin/env python3
"""Record safe Codex compaction metadata in the paired Gridline Debug timeline."""

from __future__ import annotations

import fcntl
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def safe_id(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    return re.sub(r"[^A-Za-z0-9_.:-]", "", value)[:160]


def debug_is_active(path: str) -> bool:
    try:
        state = json.loads(Path(path).read_text(encoding="utf-8"))
        return isinstance(state, dict) and state.get("active") is True
    except (OSError, ValueError):
        return False


def record(event_data: dict[str, Any]) -> None:
    event_name = event_data.get("hook_event_name")
    if event_name not in {"PreCompact", "PostCompact"}:
        return

    events_path = os.environ.get("GRIDLINE_DEBUG_EVENTS_PATH", "")
    view_path = os.environ.get("GRIDLINE_DEBUG_VIEW_STATE_PATH", "")
    if not events_path or not view_path or not debug_is_active(view_path):
        return

    trigger = event_data.get("trigger")
    if trigger not in {"manual", "auto"}:
        trigger = "unknown"
    started = event_name == "PreCompact"
    details = {
        "language": "Codex",
        "provider": "codex",
        "hookEvent": event_name,
        "trigger": trigger,
        "terminalSession": safe_id(os.environ.get("GRIDLINE_SESSION_ID")),
        "groupID": safe_id(os.environ.get("GRIDLINE_GROUP_ID")),
        "groupName": os.environ.get("GRIDLINE_GROUP_NAME", "")[:120],
        "codexSessionID": safe_id(event_data.get("session_id")),
        "turnID": safe_id(event_data.get("turn_id")),
        "pipeline": (
            "Codex CLI " + event_name + " > gridline/hooks/gridline_codex_hook.py:record "
            "> gridline_debug/events.jsonl > gridline_debug/collect_debug_logs.py:collect "
            "> gridline_debug/timeline.jsonl"
        ),
    }
    row = {
        "time": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
        "app": "Gridline",
        "event": "provider.compactionStarted" if started else "provider.compactionCompleted",
        "element": "gridline.session.hooks.codex.compaction",
        "details": details,
    }
    encoded = (json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
    try:
        descriptor = os.open(events_path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX)
            os.write(descriptor, encoded)
        finally:
            os.close(descriptor)
    except OSError:
        return


def main() -> None:
    try:
        value = json.load(sys.stdin)
        if isinstance(value, dict):
            record(value)
    except (json.JSONDecodeError, OSError, TypeError):
        pass
    # No hook output: a diagnostic failure must never change compaction behavior.
    sys.stdout.write("{}")


if __name__ == "__main__":
    main()
