#!/usr/bin/env python3
"""Print a concise, target-only report without saving or changing Gridline logs."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = Path.home() / "Library/Application Support/Gridline/workspace.json"
EVENTS = ROOT / "gridline_debug/events.jsonl"
TARGET_MARKERS = ("1abc",)


def load_targets():
    workspace = json.loads(WORKSPACE.read_text())
    groups = {
        group["id"]: group["name"]
        for group in workspace.get("groups", [])
        if any(marker in group.get("name", "").lower() for marker in TARGET_MARKERS)
    }
    return {
        session["id"]: groups[session["groupID"]]
        for session in workspace.get("sessions", [])
        if session.get("groupID") in groups
    }


def val(details, key):
    return details.get(key, "—")


def main():
    if not EVENTS.exists():
        print("No events.jsonl was produced (Gridline Debug may not have been open).")
        return
    try:
        sessions = load_targets()
    except (OSError, KeyError, json.JSONDecodeError) as error:
        print(f"Could not map current target workgroups to session IDs: {type(error).__name__}")
        return
    if not sessions:
        print("No saved workgroup name matched terminal 1ABC.")
        return

    selected = []
    for line in EVENTS.read_text().splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        details = event.get("details", {})
        session = details.get("session")
        name = sessions.get(session)
        if not name:
            continue
        kind = event.get("event", "")
        if kind not in {
            "terminal.inputSubmitted",
            "workspace.terminalUsageStatusChanged",
            "workspace.terminalUsageMonitorFailed",
        }:
            continue
        selected.append((event, name, details))

    if not selected:
        print("No terminal 1ABC submission or per-terminal usage events were recorded.")
        return

    last_fingerprint = None
    skipped = 0
    for event, name, details in selected:
        kind = event["event"]
        if kind == "workspace.terminalUsageStatusChanged":
            fingerprint = (
                kind,
                name,
                val(details, "status"),
                val(details, "model"),
                val(details, "inputTokens"),
                val(details, "outputTokens"),
                val(details, "totalTokens"),
                val(details, "latestTurnInputTokens"),
                val(details, "latestTurnOutputTokens"),
                val(details, "submissionID"),
                val(details, "reason"),
            )
            if fingerprint == last_fingerprint:
                skipped += 1
                continue
            last_fingerprint = fingerprint
        else:
            last_fingerprint = None

        timestamp = event.get("time", "unknown time")
        prefix = details.get("featurePrefix", "TERMINAL_HEADER")
        if kind == "terminal.inputSubmitted":
            message = (
                f"{timestamp} · {name} · {prefix} · ENTER submitted · "
                f"typed={val(details, 'typedCharacterCount')} chars · "
                f"pasted={val(details, 'pastedCharacterCount')} chars · "
                f"submission={val(details, 'submissionID')} · "
                f"path={val(details, 'pipeline')}"
            )
        else:
            message = (
                f"{timestamp} · {name} · {prefix} · {kind} · "
                f"status={val(details, 'status')} · model={val(details, 'model')} · "
                f"IN={val(details, 'inputTokens')} · OUT={val(details, 'outputTokens')} · "
                f"TOTAL={val(details, 'totalTokens')} · "
                f"turnIN={val(details, 'latestTurnInputTokens')} · "
                f"turnOUT={val(details, 'latestTurnOutputTokens')} · "
                f"submission={val(details, 'submissionID')} · "
                f"resolution={val(details, 'submissionResolution')} · "
                f"reason={val(details, 'reason')} · candidates={val(details, 'candidateCount')} · "
                f"rows={val(details, 'rowsRead')}/{val(details, 'usageRowsParsed')} · "
                f"path={val(details, 'pipeline')}"
            )
        print(message)
    if skipped:
        print(f"({skipped} identical repeated usage poll(s) omitted.)")


if __name__ == "__main__":
    main()
