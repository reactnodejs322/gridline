#!/usr/bin/env python3
"""Estimate Codex token history at published OpenAI API rates.

This is an API-equivalent comparison, not a ChatGPT subscription bill. It reads
only token-count and model metadata from local Codex rollout files.
Before maintaining rates, follow gridline/usage/README.md and verify the
official OpenAI API pricing page; this bundled table is a local snapshot.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

PRICING_SOURCE = "https://developers.openai.com/api/docs/pricing"
PRICING_LAST_VERIFIED = "2026-10-07"
# PRICING TABLE MAINTENANCE FOR CODING LLMS:
# Before editing the rates below, check the current official OpenAI API
# rate card: https://developers.openai.com/api/docs/pricing
# Update exact model IDs and token categories from that page, then update
# PRICING_LAST_VERIFIED. Do not guess an unpublished model price; leave it
# unpriced. Values are USD per million tokens: input, cached input, cache
# write, and output. These are API rates, not ChatGPT plan fees.
PRICING_PER_MILLION = {
    # Standard, short-context USD rates: input, cached input, cache write, output.
    "gpt-6-luna": (0.05, 0.005, 0.0625, 0.25),
    "gpt-6.1-sol": (1.00, 0.05, 1.25, 5.00),
    "gpt-6-astra": (5.00, 0.50, 6.25, 25.00),
}
SESSION_ROOT = Path.home() / ".codex" / "sessions"
CACHE_PATH = Path.home() / "Library" / "Application Support" / "Gridline" / "codex-cost-cache.json"


def price_usage(model: str, usage: dict[str, Any]) -> float | None:
    rates = PRICING_PER_MILLION.get(model.lower())
    if rates is None:
        return None
    input_tokens = max(0, int(usage.get("input_tokens") or 0))
    cached_tokens = min(input_tokens, max(0, int(usage.get("cached_input_tokens") or 0)))
    write_tokens = min(input_tokens - cached_tokens, max(0, int(usage.get("cache_write_input_tokens") or 0)))
    uncached_tokens = input_tokens - cached_tokens - write_tokens
    output_tokens = max(0, int(usage.get("output_tokens") or 0))
    return (
        uncached_tokens * rates[0]
        + cached_tokens * rates[1]
        + write_tokens * rates[2]
        + output_tokens * rates[3]
    ) / 1_000_000


def read_cache() -> dict[str, Any]:
    try:
        value = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def write_cache(value: dict[str, Any]) -> None:
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        temporary = CACHE_PATH.with_suffix(".tmp")
        temporary.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
        temporary.replace(CACHE_PATH)
    except OSError:
        pass


def estimate_session(path: Path) -> dict[str, Any]:
    model = ""
    seen: set[tuple[Any, ...]] = set()
    priced = 0.0
    unpriced: dict[str, int] = {}
    turns = 0
    try:
        with path.open("r", encoding="utf-8") as source:
            for line in source:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                payload = record.get("payload")
                if not isinstance(payload, dict):
                    continue
                if record.get("type") == "turn_context":
                    current = payload.get("model")
                    if isinstance(current, str):
                        model = current
                    continue
                if record.get("type") != "event_msg" or payload.get("type") != "token_count":
                    continue
                info = payload.get("info") or {}
                usage = info.get("last_token_usage") if isinstance(info, dict) else None
                if not isinstance(usage, dict) or not model:
                    continue
                counts = tuple(int(usage.get(key) or 0) for key in (
                    "input_tokens", "cached_input_tokens", "cache_write_input_tokens", "output_tokens"
                ))
                signature = (model, *counts)
                if signature in seen:
                    continue
                seen.add(signature)
                turns += 1
                amount = price_usage(model, usage)
                if amount is None:
                    unpriced[model] = unpriced.get(model, 0) + 1
                else:
                    priced += amount
    except OSError:
        pass
    return {"usd": priced, "unpricedModels": unpriced, "turns": turns}


def snapshot() -> dict[str, Any]:
    cache = read_cache()
    cached_sessions = cache.get("sessions") if isinstance(cache.get("sessions"), dict) else {}
    next_sessions: dict[str, Any] = {}
    total_usd = 0.0
    unpriced: dict[str, int] = {}
    turns = 0
    session_count = 0

    try:
        paths = SESSION_ROOT.glob("**/*.jsonl")
        for path in paths:
            try:
                stat = path.stat()
            except OSError:
                continue
            key = str(path)
            old = cached_sessions.get(key)
            if isinstance(old, dict) and old.get("mtimeNs") == stat.st_mtime_ns and old.get("size") == stat.st_size:
                result = old
            else:
                estimate = estimate_session(path)
                result = {"mtimeNs": stat.st_mtime_ns, "size": stat.st_size, **estimate}
            next_sessions[key] = result
            session_count += 1
            total_usd += float(result.get("usd") or 0)
            turns += int(result.get("turns") or 0)
            for model, count in (result.get("unpricedModels") or {}).items():
                unpriced[model] = unpriced.get(model, 0) + int(count)
    except OSError:
        pass

    write_cache({"sessions": next_sessions})
    return {
        "provider": "codex",
        "available": SESSION_ROOT.is_dir(),
        "amountUSD": round(total_usd, 6),
        "estimateType": "short-context API-equivalent; not subscription billing",
        "pricingSource": PRICING_SOURCE,
        "pricedTurns": turns,
        "unpricedModels": unpriced,
        "sessionFiles": session_count,
    }


if __name__ == "__main__":
    print(json.dumps(snapshot(), separators=(",", ":")))
