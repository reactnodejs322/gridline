#!/usr/bin/env python3
"""Estimate Claude Code's rolling seven-day API-equivalent token cost.

Only assistant usage metadata is read from local Claude Code JSONL files.
Message content, prompts, and terminal output are ignored. The result is not
Claude subscription billing; Claude's local stats cache only contains a
lifetime cost total, so it is deliberately not used here.

Before maintaining rates, follow gridline/usage/README.md and verify the
official Anthropic API pricing page; this bundled table is a local snapshot.
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

SESSION_ROOT = Path.home() / ".claude" / "projects"
WINDOW = timedelta(days=7)
PRICING_SOURCE = "https://platform.claude.com/docs/en/about-claude/pricing"
PRICING_LAST_VERIFIED = "2026-10-07"

# PRICING TABLE MAINTENANCE FOR CODING LLMS:
# Before editing the rates below, check the current official Anthropic API
# rate card: https://platform.claude.com/docs/en/about-claude/pricing
# Update the exact model IDs and token rates below from that page, then update
# PRICING_LAST_VERIFIED. Do not guess a missing model's price; leave it
# unpriced. Values are USD per million tokens in this order: input, 5m cache
# write, 1h cache write, cache read, output. These are API rates, not plan fees.
PRICING_PER_MILLION = {
    "claude-fable-5-1": (10.0, 12.5, 20.0, 0.25, 50.0),
    "claude-fable-5": (10.0, 12.5, 20.0, 1.0, 50.0),
    "claude-opus-5-5": (4.0, 5.0, 8.0, 0.20, 20.0),
    "claude-opus-5": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-opus-4-8": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-opus-4-7": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-opus-4-6": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-opus-4-5": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-sonnet-5-5": (2.0, 2.5, 4.0, 0.20, 10.0),
    "claude-sonnet-5": (2.0, 2.5, 4.0, 0.20, 10.0),
    "claude-sonnet-4-6": (3.0, 3.75, 6.0, 0.30, 15.0),
    "claude-sonnet-4-5": (3.0, 3.75, 6.0, 0.30, 15.0),
    "claude-haiku-4-5": (1.0, 1.25, 2.0, 0.10, 5.0),
}


def model_family(model: str) -> str | None:
    value = model.lower().replace(".", "-")
    for family in PRICING_PER_MILLION:
        if value.startswith(family):
            return family
    return None


def number(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def estimate(model: str, usage: dict[str, Any]) -> float | None:
    family = model_family(model)
    if family is None:
        return None
    input_rate, write_5m_rate, write_1h_rate, read_rate, output_rate = PRICING_PER_MILLION[family]
    cache = usage.get("cache_creation")
    cache = cache if isinstance(cache, dict) else {}
    write_5m = number(cache.get("ephemeral_5m_input_tokens"))
    write_1h = number(cache.get("ephemeral_1h_input_tokens"))
    total_writes = number(usage.get("cache_creation_input_tokens"))
    # Older Claude records do not provide cache duration details. Price those
    # writes at the documented 5-minute rate rather than dropping them.
    write_5m += max(0, total_writes - write_5m - write_1h)
    total = (
        number(usage.get("input_tokens")) * input_rate
        + write_5m * write_5m_rate
        + write_1h * write_1h_rate
        + number(usage.get("cache_read_input_tokens")) * read_rate
        + number(usage.get("output_tokens")) * output_rate
    )
    return total / 1_000_000


def snapshot(now: datetime | None = None) -> dict[str, Any]:
    end = now or datetime.now(timezone.utc)
    start = end - WINDOW
    total_usd = 0.0
    unpriced: dict[str, int] = {}
    records = 0

    try:
        files = SESSION_ROOT.glob("**/*.jsonl")
        for path in files:
            try:
                with path.open("r", encoding="utf-8") as source:
                    for line in source:
                        try:
                            record = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        if record.get("type") != "assistant":
                            continue
                        timestamp = record.get("timestamp")
                        if not isinstance(timestamp, str):
                            continue
                        try:
                            moment = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
                        except ValueError:
                            continue
                        if moment.tzinfo is None:
                            moment = moment.replace(tzinfo=timezone.utc)
                        if not (start <= moment.astimezone(timezone.utc) <= end):
                            continue
                        message = record.get("message")
                        if not isinstance(message, dict):
                            continue
                        usage = message.get("usage")
                        model = message.get("model")
                        if not isinstance(usage, dict) or not isinstance(model, str):
                            continue
                        amount = estimate(model, usage)
                        records += 1
                        if amount is None:
                            unpriced[model] = unpriced.get(model, 0) + 1
                        else:
                            total_usd += amount
            except OSError:
                continue
    except OSError:
        return {
            "provider": "claude", "amountUSD": None, "available": False,
            "windowDays": 7, "unpricedModels": {},
        }

    return {
        "provider": "claude",
        "amountUSD": round(total_usd, 6),
        "available": SESSION_ROOT.is_dir(),
        "windowDays": 7,
        "records": records,
        "unpricedModels": unpriced,
        "estimateType": "rolling seven-day API-equivalent; not subscription billing",
        "pricingSource": PRICING_SOURCE,
    }


if __name__ == "__main__":
    print(json.dumps(snapshot(), separators=(",", ":")))
