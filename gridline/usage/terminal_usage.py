#!/usr/bin/env python3
"""Stream per-terminal usage from active local Codex and Claude sessions.

The first stdin line contains Gridline terminal IDs, shell PIDs, and launch
folders; later lines contain only a terminal ID and Enter timestamp. Output is
one JSON snapshot per line. This reads provider usage metadata only; it never
persists or emits prompts, terminal output, or typed content.

Gridline path: WorkspaceView -> TerminalUsageStatus.startMonitor -> this
reader's snapshot -> process_usage/match_files -> update_file_state ->
consume_codex/consume_claude -> TerminalUsageStatus.apply. Each terminal's
readerTrace names the Python stages that ran; keep it to source/function names.
Never use UI focus to associate a provider session with a terminal. A shared
candidate can be pinned only after one terminal submits and its provider file
updates before any competing terminal submission; otherwise leave it ambiguous.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from claude_usage import estimate as estimate_claude
from codex_cost_estimate import price_usage as price_codex
try:
    from gridline_trace import debug_event as trace_debug, stage as trace_stage
except ImportError:
    def trace_debug(*args, **kwargs) -> None:
        return None

    def trace_stage(*args, **kwargs) -> None:
        return None

CODEX_ROOT = Path.home() / ".codex" / "sessions"
CLAUDE_ROOT = Path.home() / ".claude" / "projects"
PROVIDER_NAMES = {"codex": {"codex"}, "claude": {"claude"}}
POLL_SECONDS = 3.0


def number(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def parse_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def normalized_path(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return str(Path(value).expanduser().resolve())
    except OSError:
        return os.path.normpath(os.path.expanduser(value))


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    parent: int
    name: str
    started_at: datetime


@dataclass(frozen=True)
class UsageFile:
    provider: str
    path: Path
    session_id: str
    cwd: str
    created_at: datetime | None
    modified_at: float


class ReaderStageError(Exception):
    """Carry a safe source stage to the JSON diagnostic without its message."""

    def __init__(self, stage: str, cause: Exception):
        super().__init__(type(cause).__name__)
        self.stage = stage
        self.cause_type = type(cause).__name__


def read_processes() -> dict[int, ProcessInfo]:
    environment = dict(os.environ, LC_ALL="C")
    result = subprocess.run(
        ["/bin/ps", "-Ao", "pid=", "-o", "ppid=", "-o", "comm=", "-o", "lstart="],
        capture_output=True, text=True, check=True, timeout=2, env=environment,
    )
    processes: dict[int, ProcessInfo] = {}
    for line in result.stdout.splitlines():
        fields = line.strip().split(maxsplit=7)
        if len(fields) != 8:
            continue
        try:
            pid, parent = int(fields[0]), int(fields[1])
            started = datetime.strptime(" ".join(fields[3:]), "%a %b %d %H:%M:%S %Y").astimezone()
        except ValueError:
            continue
        processes[pid] = ProcessInfo(
            pid=pid,
            parent=parent,
            name=Path(fields[2]).name.lower(),
            started_at=started.astimezone(timezone.utc),
        )
    return processes


def descendants(root_pid: int, processes: dict[int, ProcessInfo]) -> list[ProcessInfo]:
    children: dict[int, list[int]] = {}
    for process in processes.values():
        children.setdefault(process.parent, []).append(process.pid)
    found: list[ProcessInfo] = []
    pending = list(children.get(root_pid, []))
    visited: set[int] = set()
    while pending:
        pid = pending.pop()
        if pid in visited:
            continue
        visited.add(pid)
        process = processes.get(pid)
        if process is None:
            continue
        if process.name in PROVIDER_NAMES["codex"] | PROVIDER_NAMES["claude"]:
            found.append(process)
        pending.extend(children.get(pid, []))
    return found


def process_cwd(pid: int) -> str | None:
    try:
        result = subprocess.run(
            ["/usr/sbin/lsof", "-a", "-p", str(pid), "-d", "cwd", "-Fn"],
            capture_output=True, text=True, check=False, timeout=1,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    for line in result.stdout.splitlines():
        if line.startswith("n") and len(line) > 1:
            return normalized_path(line[1:])
    return None


def process_usage(terminals: list[dict[str, Any]]) -> tuple[dict[str, list[tuple[dict[str, Any], ProcessInfo, str]]], dict[str, str]]:
    processes = read_processes()
    by_provider: dict[str, list[tuple[dict[str, Any], ProcessInfo, str]]] = {"codex": [], "claude": []}
    statuses: dict[str, str] = {}
    for terminal in terminals:
        terminal_id = str(terminal.get("id", ""))
        try:
            shell_pid = int(terminal.get("shellPID") or 0)
        except (TypeError, ValueError):
            shell_pid = 0
        if not terminal_id or shell_pid <= 0:
            statuses[terminal_id] = "unavailable"
            continue
        candidates = descendants(shell_pid, processes)
        provider_processes: list[tuple[str, ProcessInfo, str]] = []
        for process in candidates:
            provider = "codex" if process.name in PROVIDER_NAMES["codex"] else "claude"
            cwd = process_cwd(process.pid) or normalized_path(str(terminal.get("directory", ""))) or ""
            provider_processes.append((provider, process, cwd))
        if not provider_processes:
            statuses[terminal_id] = "no_provider"
            continue
        for provider, process, cwd in provider_processes:
            by_provider[provider].append((terminal, process, cwd))
    return by_provider, statuses


def first_record(path: Path, provider: str) -> UsageFile | None:
    try:
        modified = path.stat().st_mtime
        with path.open("r", encoding="utf-8") as source:
            for _, line in zip(range(80), source):
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if provider == "codex":
                    payload = row.get("payload")
                    if row.get("type") != "session_meta" or not isinstance(payload, dict):
                        continue
                    cwd = normalized_path(payload.get("cwd"))
                    session_id = payload.get("id") or payload.get("session_id")
                    created = parse_datetime(payload.get("timestamp"))
                else:
                    cwd = normalized_path(row.get("cwd"))
                    session_id = row.get("sessionId") or row.get("session_id")
                    created = parse_datetime(row.get("timestamp"))
                if cwd and isinstance(session_id, str):
                    return UsageFile(provider, path, session_id, cwd, created, modified)
    except (OSError, UnicodeDecodeError):
        return None
    return None


def usage_files(provider: str, index: dict[str, tuple[int, UsageFile]]) -> list[UsageFile]:
    root = CODEX_ROOT if provider == "codex" else CLAUDE_ROOT
    if not root.is_dir():
        return []
    files: list[UsageFile] = []
    found: set[str] = set()
    try:
        paths = root.rglob("*.jsonl")
        for path in paths:
            try:
                stat = path.stat()
                if stat.st_size == 0:
                    continue
            except OSError:
                continue
            key = str(path)
            found.add(key)
            cached = index.get(key)
            if cached and cached[0] == stat.st_ino:
                previous = cached[1]
                item = UsageFile(
                    previous.provider,
                    previous.path,
                    previous.session_id,
                    previous.cwd,
                    previous.created_at,
                    stat.st_mtime,
                )
            else:
                item = first_record(path, provider)
                if item:
                    index[key] = (stat.st_ino, item)
            if item:
                files.append(item)
    except OSError:
        return []
    for stale_path in set(index) - found:
        index.pop(stale_path, None)
    return files


def match_files(
    running: list[tuple[dict[str, Any], ProcessInfo, str]],
    files: list[UsageFile],
    recent_submissions: list[tuple[float, str]],
    pinned_sessions: dict[str, tuple[int, Path]],
) -> tuple[dict[str, UsageFile], set[str], dict[str, int], set[str], dict[str, str]]:
    candidates_by_process: dict[tuple[str, int], list[UsageFile]] = {}
    process_by_terminal: dict[str, ProcessInfo] = {}
    for terminal, process, cwd in running:
        terminal_id = str(terminal["id"])
        process_by_terminal.setdefault(terminal_id, process)
        # process_usage already falls back to the terminal launch directory if
        # lsof cannot read the CLI's current folder. Do not also match that
        # launch folder after the CLI has navigated elsewhere.
        matching = [item for item in files if item.cwd == cwd]
        started = process.started_at.timestamp()
        active = [item for item in matching if item.modified_at >= started - 15]
        fresh = [
            item for item in active
            if item.created_at is not None and abs(item.created_at.timestamp() - started) <= 180
        ]
        candidates_by_process[(terminal_id, process.pid)] = fresh or active

    active_processes = {terminal_id: process.pid for terminal_id, process in process_by_terminal.items()}
    for terminal_id, (pid, path) in list(pinned_sessions.items()):
        if active_processes.get(terminal_id) != pid or path not in {item.path for item in files}:
            pinned_sessions.pop(terminal_id, None)

    assigned: dict[str, UsageFile] = {}
    ambiguous: set[str] = set()
    candidate_counts: dict[str, int] = {}
    used_paths: set[Path] = set()
    submission_resolution = {
        terminal_id: "awaiting_provider_update"
        for _, terminal_id in recent_submissions
    }
    file_by_path = {item.path: item for item in files}
    pinned_by_path: dict[Path, str] = {}
    for terminal_id, (pid, path) in pinned_sessions.items():
        if active_processes.get(terminal_id) == pid and path in file_by_path:
            assigned[terminal_id] = file_by_path[path]
            pinned_by_path[path] = terminal_id
            used_paths.add(path)
            submitted_at = max(
                (timestamp for timestamp, submitted_id in recent_submissions if submitted_id == terminal_id),
                default=None,
            )
            if submitted_at is not None and 0 <= file_by_path[path].modified_at - submitted_at <= 180:
                submission_resolution[terminal_id] = "updated_pinned_terminal_session"

    owners_by_path: dict[Path, set[str]] = {}
    for terminal, process, _ in running:
        terminal_id = str(terminal["id"])
        key = (terminal_id, process.pid)
        candidates = candidates_by_process.get(key, [])
        candidate_counts[terminal_id] = max(candidate_counts.get(terminal_id, 0), len(candidates))
        for item in candidates:
            if item.path in pinned_by_path:
                continue
            owners_by_path.setdefault(item.path, set()).add(terminal_id)
    ambiguous_paths: set[Path] = set()
    for path, owners in owners_by_path.items():
        if len(owners) < 2:
            continue
        modified_at = file_by_path[path].modified_at
        submitters = {
            terminal_id
            for submitted_at, terminal_id in recent_submissions
            if terminal_id in owners
            and terminal_id not in pinned_sessions
            and 0 <= modified_at - submitted_at <= 180
        }
        if len(submitters) == 1:
            terminal_id = next(iter(submitters))
            process = process_by_terminal.get(terminal_id)
            if process:
                pinned_sessions[terminal_id] = (process.pid, path)
                pinned_by_path[path] = terminal_id
                assigned[terminal_id] = file_by_path[path]
                used_paths.add(path)
                ambiguous.update(owners - {terminal_id})
                submission_resolution[terminal_id] = "assigned_after_terminal_submission"
                continue
        elif submitters:
            for terminal_id in submitters:
                submission_resolution[terminal_id] = "competing_terminal_submissions"
        ambiguous_paths.add(path)
        ambiguous.update(owners)

    ordered = sorted(running, key=lambda item: item[1].started_at)
    for terminal, process, _ in ordered:
        terminal_id = str(terminal["id"])
        candidates = [
            item for item in candidates_by_process.get((terminal_id, process.pid), [])
            if item.path not in used_paths
            and item.path not in ambiguous_paths
            and item.path not in pinned_by_path
        ]
        if not candidates:
            continue
        if len(candidates) == 1:
            selected = candidates[0]
        elif len(running) == 1:
            candidates.sort(key=lambda item: item.modified_at, reverse=True)
            if len(candidates) > 1 and candidates[0].modified_at - candidates[1].modified_at < 2:
                ambiguous.add(terminal_id)
                continue
            selected = candidates[0]
        else:
            ranked = sorted(
                candidates,
                key=lambda item: abs((item.created_at or process.started_at).timestamp() - process.started_at.timestamp()),
            )
            if len(ranked) > 1:
                first_distance = abs((ranked[0].created_at or process.started_at).timestamp() - process.started_at.timestamp())
                next_distance = abs((ranked[1].created_at or process.started_at).timestamp() - process.started_at.timestamp())
                if next_distance - first_distance < 5:
                    ambiguous.add(terminal_id)
                    continue
            selected = ranked[0]
        assigned[terminal_id] = selected
        used_paths.add(selected.path)
    return (
        assigned,
        ambiguous,
        candidate_counts,
        set(pinned_sessions) & set(assigned),
        submission_resolution,
    )


def empty_state(provider: str, file: UsageFile) -> dict[str, Any]:
    return {
        "provider": provider,
        "sessionID": file.session_id,
        "cwd": file.cwd,
        "offset": 0,
        "model": None,
        "models": [],
        "inputTokens": 0,
        "outputTokens": 0,
        "latestTurnInputTokens": None,
        "latestTurnOutputTokens": None,
        "latestTurnTotalTokens": None,
        "cachedInputTokens": 0,
        "cacheWriteInputTokens": 0,
        "cacheReadInputTokens": 0,
        "reasoningOutputTokens": 0,
        "totalTokens": 0,
        "amountUSD": 0.0,
        "unpricedModels": [],
        "lastTotal": None,
        "lastFallbackSignature": None,
        "updatedAt": None,
        "rowsRead": 0,
        "usageRowsParsed": 0,
    }


def record_model(state: dict[str, Any], model: str | None) -> None:
    if not model:
        return
    state["model"] = model
    if model not in state["models"]:
        state["models"].append(model)


def consume_codex(state: dict[str, Any], row: dict[str, Any]) -> bool:
    payload = row.get("payload")
    if not isinstance(payload, dict):
        return False
    if row.get("type") == "turn_context":
        record_model(state, payload.get("model"))
        return False
    if row.get("type") != "event_msg" or payload.get("type") != "token_count":
        return False
    info = payload.get("info")
    if not isinstance(info, dict):
        return False
    last = info.get("last_token_usage")
    total = info.get("total_token_usage")
    if not isinstance(last, dict):
        return False

    # Codex exposes both the newest turn and a cumulative session checkpoint.
    # Keep both: showing only total_token_usage makes a short follow-up look
    # like one unexpectedly huge request when the session total has grown.
    last_input = number(last.get("input_tokens"))
    last_output = number(last.get("output_tokens"))
    state["latestTurnInputTokens"] = last_input
    state["latestTurnOutputTokens"] = last_output
    state["latestTurnTotalTokens"] = number(last.get("total_tokens")) or last_input + last_output

    fields = {
        "input_tokens": "inputTokens",
        "output_tokens": "outputTokens",
        "cached_input_tokens": "cachedInputTokens",
        "cache_write_input_tokens": "cacheWriteInputTokens",
        "reasoning_output_tokens": "reasoningOutputTokens",
    }
    if isinstance(total, dict):
        current = {key: number(total.get(key)) for key in fields}
        current_total = number(total.get("total_tokens")) or current["input_tokens"] + current["output_tokens"]
        previous = state.get("lastTotal")
        if previous is not None:
            delta = {key: max(0, current[key] - previous[key]) for key in fields}
            if any(delta.values()):
                amount = price_codex(state.get("model") or "", {
                    "input_tokens": delta["input_tokens"],
                    "cached_input_tokens": delta["cached_input_tokens"],
                    "cache_write_input_tokens": delta["cache_write_input_tokens"],
                    "output_tokens": delta["output_tokens"],
                })
                if amount is None:
                    if state["model"] and state["model"] not in state["unpricedModels"]:
                        state["unpricedModels"].append(state["model"])
                else:
                    state["amountUSD"] += amount
        else:
            # The first observed cumulative checkpoint prices its contents once.
            amount = price_codex(state.get("model") or "", total)
            if amount is None:
                if state["model"] and state["model"] not in state["unpricedModels"]:
                    state["unpricedModels"].append(state["model"])
            else:
                state["amountUSD"] += amount
        state["lastTotal"] = current
        for source, target in fields.items():
            state[target] = current[source]
        state["totalTokens"] = current_total
    else:
        signature = tuple(number(last.get(key)) for key in fields)
        timestamp = row.get("timestamp")
        marker = (timestamp, *signature)
        if marker != state.get("lastFallbackSignature"):
            amount = price_codex(state.get("model") or "", last)
            if amount is not None:
                state["amountUSD"] += amount
            state["lastFallbackSignature"] = marker
            for source, target in fields.items():
                state[target] += number(last.get(source))
            state["totalTokens"] = state["inputTokens"] + state["outputTokens"]
    state["updatedAt"] = row.get("timestamp") or state.get("updatedAt")
    return True


def consume_claude(state: dict[str, Any], row: dict[str, Any]) -> bool:
    if row.get("type") != "assistant":
        return False
    message = row.get("message")
    if not isinstance(message, dict):
        return False
    usage = message.get("usage")
    model = message.get("model")
    if not isinstance(usage, dict) or not isinstance(model, str):
        return False
    record_model(state, model)
    input_tokens = number(usage.get("input_tokens"))
    cache_read = number(usage.get("cache_read_input_tokens"))
    cache_write = number(usage.get("cache_creation_input_tokens"))
    output_tokens = number(usage.get("output_tokens"))
    state["inputTokens"] += input_tokens + cache_read + cache_write
    state["outputTokens"] += output_tokens
    state["cachedInputTokens"] += cache_read
    state["cacheWriteInputTokens"] += cache_write
    state["cacheReadInputTokens"] += cache_read
    state["totalTokens"] += input_tokens + cache_read + cache_write + output_tokens
    amount = estimate_claude(model, usage)
    if amount is None:
        if model not in state["unpricedModels"]:
            state["unpricedModels"].append(model)
    else:
        state["amountUSD"] += amount
    state["updatedAt"] = row.get("timestamp") or state.get("updatedAt")
    return True


def update_file_state(provider: str, file: UsageFile, states: dict[str, dict[str, Any]]) -> dict[str, Any]:
    key = str(file.path)
    state = states.get(key)
    if state is None or state.get("sessionID") != file.session_id:
        state = empty_state(provider, file)
        states[key] = state
    try:
        size = file.path.stat().st_size
        if size < int(state.get("offset", 0)):
            state = empty_state(provider, file)
            states[key] = state
        with file.path.open("rb") as source:
            source.seek(int(state.get("offset", 0)))
            offset = source.tell()
            while True:
                raw = source.readline()
                if not raw or not raw.endswith(b"\n"):
                    break
                offset = source.tell()
                try:
                    row = json.loads(raw)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    continue
                if not isinstance(row, dict):
                    continue
                state["rowsRead"] += 1
                try:
                    parsed_usage = consume_codex(state, row) if provider == "codex" else consume_claude(state, row)
                except Exception as error:
                    stage = "consume_codex" if provider == "codex" else "consume_claude"
                    raise ReaderStageError(stage, error) from error
                if parsed_usage:
                    state["usageRowsParsed"] += 1
            state["offset"] = offset
    except OSError as error:
        state["readerErrorType"] = type(error).__name__
        trace_stage("terminal_usage", "update_file_state", "failed", error)
        return state
    return state


def terminal_snapshot(
    state: dict[str, Any], terminal_id: str, group_name: str, status: str = "available"
) -> dict[str, Any]:
    read_error = state.get("readerErrorType")
    amount = float(state.get("amountUSD", 0.0))
    if state.get("unpricedModels") and amount == 0:
        estimate: float | None = None
    else:
        estimate = round(amount, 8)
    result = {
        "terminalID": terminal_id,
        "status": status,
        "provider": state.get("provider"),
        "sessionID": state.get("sessionID"),
        "model": state.get("model"),
        "models": state.get("models", []),
        "inputTokens": number(state.get("inputTokens")),
        "outputTokens": number(state.get("outputTokens")),
        "latestTurnInputTokens": state.get("latestTurnInputTokens"),
        "latestTurnOutputTokens": state.get("latestTurnOutputTokens"),
        "latestTurnTotalTokens": state.get("latestTurnTotalTokens"),
        "totalTokens": number(state.get("totalTokens")),
        "cachedInputTokens": number(state.get("cachedInputTokens")),
        "cacheWriteInputTokens": number(state.get("cacheWriteInputTokens")),
        "cacheReadInputTokens": number(state.get("cacheReadInputTokens")),
        "reasoningOutputTokens": number(state.get("reasoningOutputTokens")),
        "amountUSD": estimate,
        "unpricedModels": state.get("unpricedModels", []),
        "updatedAt": state.get("updatedAt"),
        "rowsRead": number(state.get("rowsRead")),
        "usageRowsParsed": number(state.get("usageRowsParsed")),
        "readerTrace": [
            "terminal_usage.py:update_file_state",
            f"terminal_usage.py:consume_{state.get('provider', 'unknown')}",
            "terminal_usage.py:terminal_snapshot",
        ],
        "errorType": read_error,
        "diagnostic": "usage_metadata_read_failed" if read_error else "matched_session_file",
    }
    if read_error:
        result["status"] = "reader_error"
    elif not result["updatedAt"]:
        result["status"] = "pending"
    else:
        debug_signature = (
            state.get("sessionID"), result["updatedAt"], result["inputTokens"],
            result["outputTokens"], result["totalTokens"], result.get("model"),
        )
        if state.get("lastDebugSignature") != debug_signature:
            state["lastDebugSignature"] = debug_signature
            trace_debug(
                "TERMINAL_HEADER",
                "usage snapshot updated",
                group_name=group_name,
                session_id=state.get("sessionID"),
                session_input_tokens=result["inputTokens"],
                session_output_tokens=result["outputTokens"],
                session_total_tokens=result["totalTokens"],
                latest_turn_input_tokens=state.get("latestTurnInputTokens"),
                latest_turn_output_tokens=state.get("latestTurnOutputTokens"),
            )
    return result


def snapshot(
    terminals: list[dict[str, Any]],
    states: dict[str, dict[str, Any]],
    indexes: dict[str, dict[str, tuple[int, UsageFile]]],
    recent_submissions: list[tuple[float, str]],
    pinned_sessions: dict[str, dict[str, tuple[int, Path]]],
) -> dict[str, Any]:
    try:
        running, statuses = process_usage(terminals)
    except Exception as error:
        trace_stage("terminal_usage", "process_usage", "failed", error)
        raise ReaderStageError("process_usage", error) from error
    result: dict[str, dict[str, Any]] = {}
    for terminal_id, status in statuses.items():
        diagnostic = "no_provider_process" if status == "no_provider" else "invalid_terminal_process"
        result[terminal_id] = {
            "terminalID": terminal_id,
            "status": status,
            "diagnostic": diagnostic,
            "candidateCount": 0,
            "readerTrace": ["terminal_usage.py:read_processes", "terminal_usage.py:process_usage"],
        }
    latest_submission_by_terminal = {
        terminal_id: submitted_at
        for submitted_at, terminal_id in recent_submissions
    }
    for terminal_id, submitted_at in latest_submission_by_terminal.items():
        result.setdefault(terminal_id, {})["submissionAt"] = submitted_at
        result[terminal_id]["submissionResolution"] = "awaiting_provider_update"
    for provider, references in running.items():
        try:
            files = usage_files(provider, indexes[provider])
        except Exception as error:
            trace_stage("terminal_usage", "usage_files", "failed", error)
            raise ReaderStageError("usage_files", error) from error
        try:
            matched, ambiguous, candidate_counts, submission_assignments, submission_resolution = match_files(
                references,
                files,
                recent_submissions,
                pinned_sessions[provider],
            )
        except Exception as error:
            trace_stage("terminal_usage", "match_files", "failed", error)
            raise ReaderStageError("match_files", error) from error
        for terminal, process, _ in references:
            terminal_id = str(terminal["id"])
            file = matched.get(terminal_id)
            if file is None:
                count = candidate_counts.get(terminal_id, 0)
                status = "ambiguous" if terminal_id in ambiguous else "unavailable"
                diagnostic = "shared_session_file_candidate" if status == "ambiguous" else (
                    "no_recent_session_file" if count == 0 else "candidate_not_uniquely_assigned"
                )
                if status == "unavailable" and (datetime.now(timezone.utc) - process.started_at).total_seconds() < 45:
                    status = "pending"
                    diagnostic = "waiting_for_session_file"
                result[terminal_id] = {
                    "terminalID": terminal_id,
                    "status": status,
                    "provider": provider,
                    "providerProcessStartedAt": process.started_at.isoformat(),
                    "candidateCount": count,
                    "diagnostic": diagnostic,
                    "readerTrace": ["terminal_usage.py:usage_files", "terminal_usage.py:match_files"],
                }
                if terminal_id in latest_submission_by_terminal:
                    result[terminal_id]["submissionAt"] = latest_submission_by_terminal[terminal_id]
                    result[terminal_id]["submissionResolution"] = submission_resolution.get(
                        terminal_id,
                        "awaiting_provider_update",
                    )
                continue
            try:
                state = update_file_state(provider, file, states)
            except ReaderStageError:
                raise
            except Exception as error:
                trace_stage("terminal_usage", "update_file_state", "failed", error)
                raise ReaderStageError("update_file_state", error) from error
            item = terminal_snapshot(state, terminal_id, str(terminal.get("groupName") or "Unknown workgroup"))
            item["candidateCount"] = candidate_counts.get(terminal_id, 1)
            item["providerProcessStartedAt"] = process.started_at.isoformat()
            item["readerTrace"] = [
                "terminal_usage.py:usage_files",
                "terminal_usage.py:match_files",
                *item["readerTrace"],
            ]
            if terminal_id in submission_assignments:
                item["diagnostic"] = "assigned_after_terminal_submission"
            if terminal_id in latest_submission_by_terminal:
                item["submissionAt"] = latest_submission_by_terminal[terminal_id]
                item["submissionResolution"] = submission_resolution.get(
                    terminal_id,
                    "awaiting_provider_update",
                )
            result[terminal_id] = item
    return {"terminals": list(result.values()), "timestamp": datetime.now(timezone.utc).isoformat()}


def read_submission_updates(submissions: list[tuple[float, str]], lock: threading.Lock) -> None:
    for line in sys.stdin:
        try:
            update = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(update, dict):
            continue
        terminal_id = update.get("terminalID")
        try:
            submitted_at = float(update.get("submittedAt"))
        except (TypeError, ValueError):
            continue
        if not isinstance(terminal_id, str) or not terminal_id:
            continue
        with lock:
            submissions.append((submitted_at, terminal_id))
            submissions[:] = submissions[-100:]


def main() -> int:
    try:
        request = json.loads(sys.stdin.readline())
    except (json.JSONDecodeError, OSError):
        return 2
    terminals = request.get("terminals", []) if isinstance(request, dict) else []
    if not isinstance(terminals, list):
        return 2
    states: dict[str, dict[str, Any]] = {}
    indexes: dict[str, dict[str, tuple[int, UsageFile]]] = {"codex": {}, "claude": {}}
    pinned_sessions: dict[str, dict[str, tuple[int, Path]]] = {"codex": {}, "claude": {}}
    submissions: list[tuple[float, str]] = []
    submission_lock = threading.Lock()
    threading.Thread(target=read_submission_updates, args=(submissions, submission_lock), daemon=True).start()
    trace_stage("terminal_usage", "reader_started", "completed", terminals=len(terminals))
    while True:
        try:
            with submission_lock:
                recent_submissions = [
                    (timestamp, terminal_id)
                    for timestamp, terminal_id in submissions
                    if time.time() - timestamp <= 180
                ]
            print(json.dumps(snapshot(
                terminals,
                states,
                indexes,
                recent_submissions,
                pinned_sessions,
            ), separators=(",", ":")), flush=True)
        except Exception as error:
            # A transient provider log or process-list problem must not stop
            # the watcher. Report only the exception type, never its message,
            # because messages can contain local file paths.
            stage = error.stage if isinstance(error, ReaderStageError) else "snapshot"
            error_type = error.cause_type if isinstance(error, ReaderStageError) else type(error).__name__
            trace_stage("terminal_usage", stage, "failed", error)
            rows = [
                {
                    "terminalID": str(terminal.get("id", "")),
                    "status": "monitor_error",
                    "diagnostic": "reader_exception",
                    "errorType": error_type,
                    "readerTrace": [f"terminal_usage.py:{stage}"],
                }
                for terminal in terminals
                if isinstance(terminal, dict) and terminal.get("id")
            ]
            print(json.dumps({"terminals": rows, "timestamp": datetime.now(timezone.utc).isoformat()}), flush=True)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
