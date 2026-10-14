#!/usr/bin/env python3
"""Copy build results and Gridline events into Debug's structured timeline."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any


DEBUG = Path(__file__).resolve().parent
BUILD = DEBUG / "build"
EVENTS = DEBUG / "events.jsonl"
STATUS = BUILD / "latest-status.json"
BUILD_LOG = BUILD / "latest.log"
STATE = BUILD / "log-collector-state.json"
TIMELINE = DEBUG / "timeline.jsonl"
CLEAR_REQUEST = BUILD / "clear-logs.request"
ERRORS = BUILD / "latest-errors.txt"


def append_record(record: dict[str, Any]) -> None:
    TIMELINE.parent.mkdir(parents=True, exist_ok=True)
    with TIMELINE.open("a", encoding="utf-8") as output:
        output.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")


def record_build(status: dict[str, Any]) -> None:
    output = BUILD_LOG.read_text(encoding="utf-8", errors="replace") if BUILD_LOG.exists() else ""
    append_record({
        "time": str(status.get("time", "")),
        "app": "Gridline Debug",
        "event": "hot-reload.build",
        "element": "gridline_debug/build/latest.log",
        "details": {
            "status": str(status.get("status", "unknown")),
            "target": str(status.get("target", "Gridline + Gridline Debug")),
            "exitCode": str(status.get("exitCode", "")),
            "buildLog": output[-200_000:],
        },
    })


def load_state() -> dict[str, Any]:
    try:
        state = json.loads(STATE.read_text(encoding="utf-8"))
        if isinstance(state, dict) and TIMELINE.exists() and TIMELINE.stat().st_size:
            return state
    except (OSError, ValueError):
        pass
    return {}


def save_state(state: dict[str, Any]) -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, sort_keys=True), encoding="utf-8")
    temporary.replace(STATE)


def file_identity(path: Path) -> str:
    try:
        metadata = path.stat()
        return f"{metadata.st_dev}:{metadata.st_ino}"
    except OSError:
        return ""


def clear_logs(state: dict[str, Any]) -> None:
    for path in (TIMELINE, EVENTS, STATUS, BUILD_LOG, ERRORS):
        path.unlink(missing_ok=True)
    state.clear()
    save_state(state)
    CLEAR_REQUEST.unlink(missing_ok=True)


def collect(state: dict[str, Any]) -> None:
    if CLEAR_REQUEST.exists():
        clear_logs(state)
        return
    changed = False
    timeline_identity = file_identity(TIMELINE)
    if state.get("timeline_identity") and timeline_identity != state["timeline_identity"]:
        # Gridline starts a fresh timeline on each app launch.
        state.pop("build_key", None)
        changed = True
    if STATUS.exists():
        try:
            status = json.loads(STATUS.read_text(encoding="utf-8"))
            key = f"{status.get('time', '')}:{status.get('status', '')}"
            if key != state.get("build_key") or timeline_identity != state.get("build_timeline_identity"):
                record_build(status)
                state["build_key"] = key
                state["build_timeline_identity"] = file_identity(TIMELINE)
                changed = True
        except (OSError, ValueError):
            pass

    if EVENTS.exists():
        metadata = EVENTS.stat()
        identity = f"{metadata.st_dev}:{metadata.st_ino}"
        offset = int(state.get("events_offset", 0))
        if identity != state.get("events_identity") or metadata.st_size < offset:
            offset = 0
        with EVENTS.open("rb") as source:
            source.seek(offset)
            while line := source.readline():
                if not line.endswith(b"\n"):
                    break
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if isinstance(event, dict) and isinstance(event.get("event"), str):
                    append_record(event)
                offset = source.tell()
        if identity != state.get("events_identity") or offset != state.get("events_offset"):
            state["events_identity"] = identity
            state["events_offset"] = offset
            changed = True
    next_timeline_identity = file_identity(TIMELINE)
    if next_timeline_identity != state.get("timeline_identity"):
        state["timeline_identity"] = next_timeline_identity
        changed = True
    if changed:
        save_state(state)


def running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--watcher-pid", type=int)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    state = load_state()
    while True:
        collect(state)
        if args.once or (args.watcher_pid and not running(args.watcher_pid)):
            return
        time.sleep(0.5)


if __name__ == "__main__":
    main()
