#!/usr/bin/env python3
"""Show Codex's configured model and live ChatGPT-plan usage windows."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import selectors
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any

LOG_ROOT = Path.home() / ".codex" / "sessions"
USAGE_KEYS = (
    "input_tokens",
    "cached_input_tokens",
    "output_tokens",
    "reasoning_output_tokens",
    "total_tokens",
)


def read_default_settings() -> tuple[str, str]:
    config = Path.home() / ".codex" / "config.toml"
    model, effort = "unknown", "unknown"
    try:
        source = config.read_text(encoding="utf-8")
        model_match = re.search(r'^model\s*=\s*["\']([^"\']+)', source, re.M)
        effort_match = re.search(r'^model_reasoning_effort\s*=\s*["\']([^"\']+)', source, re.M)
        if model_match:
            model = model_match.group(1)
        if effort_match:
            effort = effort_match.group(1)
    except OSError:
        pass
    return model, effort


class AppServer:
    def __init__(self) -> None:
        codex = shutil.which("codex")
        if not codex:
            raise RuntimeError("Codex CLI was not found in PATH.")
        self.process = subprocess.Popen(
            [codex, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            bufsize=1,
        )
        self.selector = selectors.DefaultSelector()
        assert self.process.stdout is not None
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.next_id = 1
        self.request(
            "initialize",
            {
                "clientInfo": {"name": "llm_budget_monitor", "title": "LLM Budget Monitor", "version": "1.0.0"},
                "capabilities": {"experimentalApi": True},
            },
            timeout=20,
        )
        self.notify("initialized", {})

    def send(self, message: dict) -> None:
        if self.process.poll() is not None:
            raise RuntimeError("Codex app-server stopped.")
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
        self.process.stdin.flush()

    def notify(self, method: str, params: dict) -> None:
        self.send({"jsonrpc": "2.0", "method": method, "params": params})

    def request(self, method: str, params: dict, timeout: int = 20) -> dict:
        request_id = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            ready = self.selector.select(timeout=max(0, deadline - time.monotonic()))
            if not ready:
                break
            assert self.process.stdout is not None
            line = self.process.stdout.readline()
            if not line:
                break
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("id") == request_id:
                if "error" in message:
                    error = message["error"]
                    raise RuntimeError(error.get("message", str(error)))
                return message.get("result", {})
        raise RuntimeError(f"Timed out waiting for Codex response to {method}.")

    def close(self) -> None:
        self.selector.close()
        self.process.terminate()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()


def local_time(timestamp: object) -> str:
    if not isinstance(timestamp, (int, float)):
        return "reset time unavailable"
    return dt.datetime.fromtimestamp(timestamp).astimezone().strftime("%b %d, %I:%M:%S %p %Z")


def describe_window(window: object) -> list[str]:
    if not isinstance(window, dict):
        return ["Allowance window unavailable"]
    used = window.get("usedPercent")
    used = max(0, min(100, int(used))) if isinstance(used, (int, float)) else None
    duration = window.get("windowDurationMins")
    if isinstance(duration, (int, float)):
        if duration == 10080:
            label = "Weekly allowance"
        elif duration % 1440 == 0:
            span = f"{duration / 1440:g}-day"
            label = f"{span} allowance"
        elif duration % 60 == 0:
            span = f"{duration / 60:g}-hour"
            label = f"{span} allowance"
        else:
            span = f"{duration:g}-minute"
            label = f"{span} allowance"
    else:
        label = "Usage allowance"

    if used is None:
        lines = [f"{label}: percentage unavailable"]
    else:
        remaining = 100 - used
        filled = round(used / 5)
        bar = "█" * filled + "░" * (20 - filled)
        lines = [
            f"{label}: {used}% / 100% used",
            f"[{bar}] {remaining}% left",
        ]
    lines.append(f"Resets: {local_time(window.get('resetsAt'))}")
    return lines


def find_latest_log() -> Path | None:
    try:
        return max(LOG_ROOT.rglob("rollout-*.jsonl"), key=lambda p: p.stat().st_mtime)
    except (ValueError, OSError):
        return None


def safe_usage(value: Any) -> dict[str, int] | None:
    if not isinstance(value, dict) or not any(key in value for key in USAGE_KEYS):
        return None
    return {key: int(value.get(key, 0) or 0) for key in USAGE_KEYS}


class SessionState:
    """Read only usage and model metadata from a local Codex session log."""

    def __init__(self) -> None:
        self.offset = 0
        self.model = "unknown"
        self.effort = "unknown"
        self.turn_id: str | None = None
        self.active = False
        self.turn_usage: dict[str, int] | None = None
        self.last_response_usage: dict[str, int] | None = None
        self.thread_usage: dict[str, int] | None = None
        self.context_window: int | None = None
        self.last_update: str | None = None

    def read_new(self, path: Path) -> bool:
        changed = False
        try:
            if path.stat().st_size < self.offset:
                self.__init__()
            with path.open("rb") as stream:
                stream.seek(self.offset)
                for raw in stream:
                    try:
                        entry = json.loads(raw)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        continue
                    changed = self.consume(entry) or changed
                self.offset = stream.tell()
        except OSError:
            return changed
        return changed

    def consume(self, entry: dict[str, Any]) -> bool:
        kind = entry.get("type")
        payload = entry.get("payload")
        if not isinstance(payload, dict):
            return False
        if kind == "turn_context":
            self.model = payload.get("model") or self.model
            self.effort = payload.get("effort") or self.effort
            return True
        if kind == "event_msg":
            event_type = payload.get("type")
            if event_type == "task_started":
                self.turn_id = payload.get("turn_id")
                self.active = True
                self.turn_usage = None
                self.last_response_usage = None
                self.last_update = entry.get("timestamp")
                return True
            if event_type == "task_complete" and payload.get("turn_id") == self.turn_id:
                self.active = False
                self.last_update = entry.get("timestamp")
                return True
            if event_type == "token_count":
                info = payload.get("info", {})
                if isinstance(info, dict):
                    self.context_window = info.get("model_context_window") or self.context_window
                    latest = safe_usage(info.get("last_token_usage"))
                    if latest:
                        self.last_response_usage = latest
                        self.thread_usage = safe_usage(info.get("total_token_usage")) or self.thread_usage
                        self.last_update = entry.get("timestamp")
                        return True
        if kind == "token_usage_record":
            usage = safe_usage(payload.get("usage"))
            turn_usage = safe_usage(payload.get("turn_token_usage"))
            thread_usage = safe_usage(payload.get("thread_token_usage"))
            if turn_usage or usage:
                self.turn_id = payload.get("turn_id") or self.turn_id
                self.turn_usage = turn_usage or usage
                self.last_response_usage = usage or self.last_response_usage
                self.thread_usage = thread_usage or self.thread_usage
                self.last_update = entry.get("timestamp")
                return True
        return False


class UsageSnapshot:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.result: dict | None = None
        self.error: str | None = None
        self.updated: str | None = None
        self.revision = 0
        self.previous_primary_used: int | None = None
        self.primary_change: int | None = None

    def set(self, result: dict | None = None, error: str | None = None) -> None:
        with self.lock:
            old_used = self.previous_primary_used
            self.result = result
            self.error = error
            self.updated = dt.datetime.now().astimezone().strftime("%b %d, %I:%M:%S %p %Z")
            new_used = primary_used_percent(result)
            self.primary_change = new_used - old_used if new_used is not None and old_used is not None else None
            self.previous_primary_used = new_used
            self.revision += 1

    def get(self) -> tuple[dict | None, str | None, str | None, int, int | None]:
        with self.lock:
            return self.result, self.error, self.updated, self.revision, self.primary_change


def primary_used_percent(result: dict | None) -> int | None:
    if not isinstance(result, dict):
        return None
    account = result.get("rateLimitsByLimitId") or {}
    allowance = account.get("codex") if isinstance(account, dict) else None
    allowance = allowance or result.get("rateLimits") or {}
    primary = allowance.get("primary") if isinstance(allowance, dict) else None
    used = primary.get("usedPercent") if isinstance(primary, dict) else None
    return int(used) if isinstance(used, (int, float)) else None


def usage_window_snapshot(value: object) -> dict[str, int | float | None] | None:
    if not isinstance(value, dict):
        return None
    used = value.get("usedPercent")
    duration = value.get("windowDurationMins")
    resets = value.get("resetsAt")
    return {
        "usedPercent": int(used) if isinstance(used, (int, float)) else None,
        "windowDurationMins": int(duration) if isinstance(duration, (int, float)) else None,
        "resetsAt": float(resets) if isinstance(resets, (int, float)) else None,
    }


def json_snapshot(
    model: str,
    effort: str,
    result: dict | None,
    usage_error: str | None,
    usage_updated: str | None,
    session: SessionState,
) -> dict[str, Any]:
    account = result.get("rateLimitsByLimitId") or {} if isinstance(result, dict) else {}
    allowance = account.get("codex") if isinstance(account, dict) else None
    allowance = allowance or (result.get("rateLimits") if isinstance(result, dict) else None) or {}
    if not isinstance(allowance, dict):
        allowance = {}
    return {
        "plan": allowance.get("planType"),
        "primary": usage_window_snapshot(allowance.get("primary")),
        "secondary": usage_window_snapshot(allowance.get("secondary")),
        "threadTokens": session.thread_usage.get("total_tokens") if session.thread_usage else None,
        "model": session.model if session.model != "unknown" else model,
        "effort": session.effort if session.effort != "unknown" else effort,
        "updated": usage_updated,
        "error": usage_error,
    }


def poll_allowance(snapshot: UsageSnapshot, stop: threading.Event, interval: float) -> None:
    server = None
    try:
        server = AppServer()
        while not stop.is_set():
            try:
                result = server.request(
                    "account/rateLimits/read",
                    {"excludeResetCreditDetails": True},
                    timeout=30,
                )
                snapshot.set(result=result)
            except (OSError, RuntimeError, json.JSONDecodeError) as exc:
                snapshot.set(error=str(exc))
                return
            if stop.wait(interval):
                return
    except (OSError, RuntimeError) as exc:
        snapshot.set(error=str(exc))
    finally:
        if server:
            server.close()


def format_usage_line(label: str, usage: dict[str, int] | None) -> list[str]:
    if not usage:
        return []
    return [
        f"{label}: {usage['total_tokens']:,} tokens",
        f"  Input          {usage['input_tokens']:>12,} tokens",
        f"  Cached input   {usage['cached_input_tokens']:>12,} tokens",
        f"  Output         {usage['output_tokens']:>12,} tokens",
        f"  Reasoning      {usage['reasoning_output_tokens']:>12,} tokens",
    ]


BOX_WIDTH = 72


def box_line(text: str = "") -> str:
    if len(text) > BOX_WIDTH:
        text = text[: BOX_WIDTH - 1] + "…"
    return f"│ {text:<{BOX_WIDTH}} │"


def box_rule() -> str:
    return "├" + "─" * (BOX_WIDTH + 2) + "┤"


def render(
    model: str,
    effort: str,
    result: dict | None,
    usage_error: str | None,
    usage_updated: str | None,
    session: SessionState,
    interval: int,
    live: bool,
    primary_change: int | None = None,
) -> None:
    if live and sys.stdout.isatty():
        sys.stdout.write("\033[2J\033[H")
    print("╭" + " Codex live usage ".center(BOX_WIDTH + 2, "─") + "╮")
    current_model = session.model if session.model != "unknown" else model
    current_effort = session.effort if session.effort != "unknown" else effort
    print(box_line("MODEL"))
    print(box_line(f"{current_model} / {current_effort}"))
    if session.turn_id:
        print(box_line("Working" if session.active else "Waiting for next turn"))
    print(box_rule())
    if result is None:
        print(box_line(f"PLAN  {'Checking allowance…' if usage_error is None else 'Allowance unavailable'}"))
    else:
        account = result.get("rateLimitsByLimitId") or {}
        allowance = account.get("codex") if isinstance(account, dict) else None
        allowance = allowance or result.get("rateLimits") or {}
        if not isinstance(allowance, dict):
            allowance = {}
        plan = allowance.get("planType")
        print(box_line(f"PLAN  {(plan or 'unknown').upper()}"))
        print(box_line("ALLOWANCE"))
        for line in describe_window(allowance.get("primary")):
            print(box_line(line))
        primary = allowance.get("primary")
        primary_duration = primary.get("windowDurationMins") if isinstance(primary, dict) else None
        if primary_change is not None:
            direction = "used" if primary_change > 0 else "returned" if primary_change < 0 else "no change"
            delta = f"{abs(primary_change)} percentage point{'s' if abs(primary_change) != 1 else ''}"
            period = f"since last check ({interval}s)"
            print(box_line(f"Change {period}: {delta} {direction}" if primary_change else f"Change {period}: no change reported"))
        else:
            print(box_line("Change since last check: collecting baseline…" if live else "Change rate: start live monitor to collect samples"))
        if primary_duration == 10080:
            print(box_line("Observed change is allowance percentage, not tokens; shared across models/sessions."))
        if allowance.get("secondary") is not None:
            for line in describe_window(allowance.get("secondary")):
                print(box_line(line))
        credits = allowance.get("credits")
        if isinstance(credits, dict):
            if credits.get("unlimited"):
                print(box_line("Additional credits: unlimited"))
            elif credits.get("balance") is not None:
                print(box_line(f"Additional credits: {credits['balance']}"))
        if result.get("ordinaryUsageAllowed") is False:
            print(box_line("Included usage is currently unavailable."))
        print(box_line(f"Updated: {usage_updated or 'waiting'}"))
    if usage_error:
        print(box_line(f"Refresh error: {usage_error}"))
    print(box_rule())
    print(box_line("TOKEN USAGE"))
    if session.last_response_usage:
        for line in format_usage_line("Latest model request", session.last_response_usage):
            print(box_line(line))
    if session.turn_usage:
        for line in format_usage_line("Turn cumulative usage", session.turn_usage):
            print(box_line(line))
    elif not session.last_response_usage:
        print(box_line("Waiting for a Codex usage record…"))
    if session.thread_usage:
        print(box_rule())
        print(box_line(f"SESSION TOTAL   {session.thread_usage['total_tokens']:,} tokens"))
    if session.context_window:
        print(box_line(f"Context window: {session.context_window:,} tokens"))
    if session.last_update:
        print(box_line(f"Latest token update: {session.last_update}"))
    print(box_rule())
    print(box_line("Input includes repeated context; separate from plan allowance."))
    print(box_line("Counts update after each response/tool cycle. Ctrl+C to stop."))
    print("╰" + "─" * (BOX_WIDTH + 2) + "╯")
    if live:
        print(f"Allowance refreshes every {interval}s. Local Codex sessions only.")
    sys.stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interval", type=float, default=60, help="plan allowance refresh interval in seconds")
    parser.add_argument("--once", action="store_true", help="show one snapshot and exit")
    parser.add_argument("--json", action="store_true", help="emit a machine-readable snapshot; requires --once")
    parser.add_argument("--watch-json", action="store_true", help="keep one Codex app-server open and emit JSON snapshots as allowance updates arrive")
    args = parser.parse_args()
    if args.watch_json and args.interval < 1:
        parser.error("--watch-json interval must be at least 1 second")
    if not args.once and not args.watch_json and args.interval < 10:
        parser.error("interactive interval must be at least 10 seconds")
    if args.json and not args.once:
        parser.error("--json requires --once")
    if args.watch_json and (args.once or args.json):
        parser.error("--watch-json cannot be combined with --once or --json")

    model, effort = read_default_settings()
    stop = threading.Event()
    usage_snapshot = UsageSnapshot()
    current_path: Path | None = None
    session = SessionState()
    usage_thread: threading.Thread | None = None
    try:
        if args.once:
            server = AppServer()
            try:
                result = server.request(
                    "account/rateLimits/read",
                    {"excludeResetCreditDetails": True},
                    timeout=30,
                )
                usage_snapshot.set(result=result)
            finally:
                server.close()
            path = find_latest_log()
            if path:
                session.read_new(path)
            result, error, updated, _, change = usage_snapshot.get()
            if args.json:
                print(json.dumps(json_snapshot(model, effort, result, error, updated, session), separators=(",", ":")))
            else:
                render(model, effort, result, error, updated, session, args.interval, False, change)
            return 0

        usage_thread = threading.Thread(
            target=poll_allowance,
            args=(usage_snapshot, stop, args.interval),
            daemon=True,
        )
        usage_thread.start()
        last_revision = -1
        while True:
            newest = find_latest_log()
            token_changed = False
            if newest != current_path:
                current_path = newest
                session = SessionState()
                if current_path is not None:
                    token_changed = session.read_new(current_path)
                token_changed = True
            elif current_path is not None:
                token_changed = session.read_new(current_path)
            result, error, updated, revision, change = usage_snapshot.get()
            if args.watch_json:
                if revision != last_revision:
                    print(json.dumps(json_snapshot(model, effort, result, error, updated, session), separators=(",", ":")), flush=True)
                    last_revision = revision
                if error:
                    return 1
            elif token_changed or revision != last_revision:
                render(model, effort, result, error, updated, session, args.interval, True, change)
                last_revision = revision
            time.sleep(0.5)
    except KeyboardInterrupt:
        return 0
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"Could not read Codex usage: {exc}", file=sys.stderr)
        print("Try updating Codex, then run `codex /status` or open Settings → Usage.", file=sys.stderr)
        return 1
    finally:
        stop.set()
        if usage_thread:
            usage_thread.join(timeout=2)


if __name__ == "__main__":
    raise SystemExit(main())
