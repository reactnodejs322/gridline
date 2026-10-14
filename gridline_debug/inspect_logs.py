#!/usr/bin/env python3
"""Print filtered Gridline Debug timeline entries for shell troubleshooting."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TIMELINE = Path(__file__).resolve().parent / "timeline.jsonl"
VIEW_STATE = Path(__file__).resolve().parent / "user-log-view.json"
SOURCE_PATHS = {
    "Workspace.swift": "gridline/Sources/Gridline/Workspace.swift",
    "ProviderUsageService.swift": "gridline/Sources/Gridline/ProviderUsageService.swift",
    "DebugEvents.swift": "gridline/Sources/Gridline/DebugEvents.swift",
    "MainTemplateWorkGroupCard.swift": "gridline/template/main_template/MainTemplateWorkGroupCard.swift",
    "terminal_usage.py": "gridline/usage/terminal_usage.py",
    "claude_usage.py": "gridline/usage/claude_usage.py",
    "monitor.py": "gridline/usage/monitor.py",
}
SYMBOL_FILES = {
    "WorkspaceView": "gridline/Sources/Gridline/Workspace.swift",
    "ProviderUsageService": "gridline/Sources/Gridline/ProviderUsageService.swift",
    "TerminalUsageStatus": "gridline/Sources/Gridline/ProviderUsageService.swift",
    "CodexUsageStatus": "gridline/Sources/Gridline/ProviderUsageService.swift",
}
PIPELINE_FILE = re.compile(r"(?P<path>(?:[\w.-]+/)*[\w.-]+\.(?:swift|py))(?P<suffix>:[\w./-]+)?")
PIPELINE_SYMBOL = re.compile(r"(?<![:\w/])(?P<symbol>WorkspaceView|ProviderUsageService|TerminalUsageStatus|CodexUsageStatus)\.(?P<member>[\w/]+)")


def expand_code_path(pipeline: str) -> str:
    def replace_file(match: re.Match) -> str:
        filename = match.group("path").rsplit("/", 1)[-1]
        path = SOURCE_PATHS.get(filename)
        return f"{path}{match.group('suffix') or ''}" if path else match.group(0)

    expanded = PIPELINE_FILE.sub(replace_file, pipeline)
    return PIPELINE_SYMBOL.sub(
        lambda match: f"{SYMBOL_FILES[match.group('symbol')]}:{match.group('member')}",
        expanded,
    )


def source_for(name: str, details: dict) -> str:
    if details.get("language") == "Codex":
        return "codex"
    if details.get("language") == "Python":
        return "python"
    if details.get("language") == "Swift":
        return "swift"
    if name == "hot-reload.build":
        return "build"
    if name.startswith(("runtime.", "workspace.terminalUsage")):
        return "swift"
    return "ui"


def is_failure(name: str, details: dict) -> bool:
    return ("failed" in name.lower()
            or details.get("status") in {"failed", "reader_error"}
            or name == "workspace.terminalUsageMonitorFailed")


def export_text(record: dict) -> str:
    details = record.get("details", {})
    fields = " · ".join(f"{key}={details[key]}" for key in sorted(details))
    return f"{record.get('time', '')} [{source_for(str(record.get('event', '')), details)}] {record.get('event', '')} — {fields}"


def category_matches(name: str, details: dict[str, str], category: str) -> bool:
    source = source_for(name, details)
    if category == "all":
        return True
    if category == "terminal":
        return name in {"prompt.submitted", "terminal.inputSubmitted", "runtime.pythonDebug"} or name.startswith("workspace.terminalUsage")
    if category == "prompts":
        return name in {"prompt.submitted", "terminal.inputSubmitted"}
    if category == "usage":
        return name.startswith("workspace.terminalUsage")
    if category == "hooks":
        return name.startswith("provider.")
    if category == "failures":
        return is_failure(name, details)
    return source == category


def summary_for(record: dict) -> str:
    details = record.get("details", {})
    name = str(record.get("event", "event"))
    group = str(details.get("groupName", ""))
    prefix = f"{group} · " if group else ""
    if name == "prompt.submitted":
        return f"{prefix}Prompt: {details.get('prompt', '')}"
    if name == "terminal.inputSubmitted":
        return f"{prefix}Submitted #{str(details.get('submissionID', ''))[:8]} · {details.get('characterCount', '?')} characters"
    if name == "workspace.terminalUsageStatusChanged":
        return (f"{prefix}SESSION IN {details.get('inputTokens', '—')}  OUT {details.get('outputTokens', '—')}"
                f"  TOTAL {details.get('totalTokens', '—')} · TURN IN {details.get('latestTurnInputTokens', '—')}"
                f"  OUT {details.get('latestTurnOutputTokens', '—')} · {details.get('status', 'unknown')}")
    if name == "runtime.pythonDebug":
        return f"{prefix}{details.get('featurePrefix', 'Python DEBUG')} · {details.get('counts', '')}"
    if name == "hot-reload.build":
        return f"Build {details.get('status', 'unknown')} · {details.get('target', 'Gridline')}"
    if name == "provider.compactionStarted":
        return f"{prefix}Compaction starting · {details.get('trigger', 'unknown')} · terminal {details.get('terminalSession', 'unknown')}"
    if name == "provider.compactionCompleted":
        return f"{prefix}Compaction completed · {details.get('trigger', 'unknown')} · terminal {details.get('terminalSession', 'unknown')}"
    if name == "provider.hooksConfigured":
        return f"{prefix}Codex hooks {details.get('action', 'updated')} · {details.get('status', 'unknown')}"
    if name == "provider.hooksPanelOpened":
        return f"{prefix}Project hooks opened"
    if name == "provider.ponytailVendorUpdated":
        return f"Ponytail source updated · v{details.get('version', 'unknown')} · {details.get('commit', 'unknown')}"
    if name == "workgroup.actionsMenuToggled":
        state = "opened" if details.get("expanded") == "true" else "closed"
        return f"{prefix}Work-group actions {state}"
    if name == "workspace.utilityMenuToggled":
        state = "opened" if details.get("expanded") == "true" else "closed"
        return f"Workspace controls {state}"
    status = details.get("status", details.get("reason", ""))
    return f"{prefix}{name}{f' · {status}' if status else ''}"


def code_path_steps(pipeline: str) -> list[dict[str, str]]:
    expanded = expand_code_path(pipeline)
    steps = []
    for item in re.split(r"\s*>\s*|\s*;\s*awaiting\s*", expanded):
        item = item.strip()
        if not item:
            continue
        file_path, separator, symbol = item.partition(":")
        if file_path.endswith((".swift", ".py")):
            step = {"file": file_path}
            if separator and symbol:
                step["symbol"] = symbol
        else:
            step = {"step": item}
        steps.append(step)
    return steps


def llm_entry(record: dict) -> dict:
    details = dict(record.get("details", {}))
    pipeline = str(details.get("pipeline", ""))
    if pipeline:
        details["pipeline"] = expand_code_path(pipeline)
    return {
        "time_utc": record.get("time", ""),
        "source": source_for(str(record.get("event", "")), details).title(),
        "event": record.get("event", ""),
        "workgroup": details.get("groupName", ""),
        "summary": summary_for(record),
        "is_failure": is_failure(str(record.get("event", "")), details),
        "code_path": code_path_steps(pipeline) if pipeline else [],
        "details": details,
    }


def print_llm_snapshot(state: dict, category: str, workgroup: str, search: str,
                       matches: list[dict], shown: list[dict]) -> None:
    snapshot = {
        "kind": "gridline_debug_log_snapshot",
        "snapshot_time_utc": state.get("updatedAt", "unknown"),
        "window_active": bool(state.get("active", False)),
        "filters": {
            "show": state.get("show", category),
            "category": category,
            "workgroup": workgroup,
            "search": search,
            "following": bool(state.get("following", True)),
        },
        "matching_entry_count": len(matches),
        "returned_entry_count": len(shown),
        "omitted_older_matching_entries": len(matches) - len(shown),
        "entries": [llm_entry(record) for record in shown],
    }
    print(json.dumps(snapshot, ensure_ascii=False, indent=2))


def show_user_log_filters(args, parser) -> None:
    if not VIEW_STATE.exists():
        parser.exit(1, f"Gridline Debug has not published its active log view yet: {VIEW_STATE}\nOpen Gridline Debug and try again.\n")
    try:
        state = json.loads(VIEW_STATE.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Could not read Gridline Debug's active log view: {error}\n")

    category = str(state.get("category", "all"))
    workgroup = str(state.get("workgroup", "All workgroups"))
    search = str(state.get("search", "")).strip()
    matches = []
    if TIMELINE.exists():
        for line in TIMELINE.read_text(encoding="utf-8").splitlines():
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if not isinstance(record, dict) or not isinstance(record.get("details"), dict):
                continue
            details = record["details"]
            name = str(record.get("event", ""))
            if not category_matches(name, details, category):
                continue
            if workgroup != "All workgroups" and str(details.get("groupName", "")) != workgroup:
                continue
            if search and search.casefold() not in export_text(record).casefold():
                continue
            matches.append(record)

    limit = max(args.limit, 0)
    shown = matches if limit == 0 else matches[-limit:]
    if args.output_format == "llm":
        print_llm_snapshot(state, category, workgroup, search, matches, shown)
        return
    print("Gridline Debug active log view")
    print(f"Window active: {'yes' if state.get('active', False) else 'no (last recorded view)'}")
    print(f"Updated: {state.get('updatedAt', 'unknown')}")
    print(f"Show: {state.get('show', category)}")
    print(f"Workgroup: {workgroup}")
    print(f"Search: {search if search else '(empty)'}")
    print(f"Following: {'on' if state.get('following', True) else 'off'}")
    print(f"Matching entries: {len(matches)} · showing {len(shown)}")
    print()
    for record in shown:
        print(display(record, args.details))


def display(record: dict, details_mode: bool) -> str:
    details = record.get("details", {})
    name = record.get("event", "event")
    summary = summary_for(record)
    source = source_for(name, details).title()
    heading = f"{record.get('time', '')} [{source}] {name} — {summary}"
    pipeline = details.get("pipeline")
    if pipeline:
        heading += f"\n  CODE PATH: {expand_code_path(str(pipeline))}"
    if details_mode:
        expanded_details = dict(details)
        if pipeline:
            expanded_details["pipeline"] = expand_code_path(str(pipeline))
        heading += "\n" + json.dumps(expanded_details, indent=2, ensure_ascii=False)
    return heading


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("view", nargs="?", choices=("showUserlogFilters",), help="show Gridline Debug's active Show, Workgroup, Search, and matching logs")
    parser.add_argument("--category", choices=("terminal", "prompts", "usage", "hooks", "python", "swift", "ui", "build", "failures", "all"))
    parser.add_argument("--group", default="", help="Workgroup name, case insensitive")
    parser.add_argument("--search", default="", help="Search all fields, case insensitive")
    parser.add_argument("--limit", type=int, default=30)
    parser.add_argument("--details", action="store_true")
    parser.add_argument("--format", dest="output_format", choices=("text", "llm"))
    args = parser.parse_args()
    if args.view == "showUserlogFilters":
        args.output_format = args.output_format or "llm"
        show_user_log_filters(args, parser)
        return
    args.output_format = args.output_format or "text"
    category = args.category or "terminal"
    if not TIMELINE.exists():
        parser.exit(1, f"No timeline yet: {TIMELINE}\n")
    matches = []
    for line in TIMELINE.read_text(encoding="utf-8").splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if not isinstance(record, dict) or not isinstance(record.get("details"), dict):
            continue
        details = record["details"]
        name = str(record.get("event", ""))
        if not category_matches(name, details, category):
            continue
        if args.group.casefold() not in str(details.get("groupName", "")).casefold():
            continue
        if args.search.casefold() not in json.dumps(record, ensure_ascii=False).casefold():
            continue
        matches.append(record)
    for record in matches[-max(args.limit, 0):]:
        if args.output_format == "llm":
            print(json.dumps(llm_entry(record), ensure_ascii=False, indent=2))
        else:
            print(display(record, args.details))


if __name__ == "__main__":
    main()
