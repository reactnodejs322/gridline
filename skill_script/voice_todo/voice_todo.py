#!/usr/bin/env python3
"""Watch a temporary chunk queue and transcribe each short mic chunk with bundled MLX Whisper."""

import json
import math
import re
import sys
import time
from pathlib import Path


WAKE_PHRASE = re.compile(
    r"\b(?:(?:okay|ok)[, .!?;:-]*(?:next[, .!?;:-]*)?|next[, .!?;:-]*)problem\b",
    re.IGNORECASE,
)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: voice_todo.py QUEUE_DIRECTORY MODEL_DIRECTORY", file=sys.stderr)
        return 2

    queue = Path(sys.argv[1])
    model = Path(sys.argv[2])
    queue.mkdir(parents=True, exist_ok=True)
    try:
        import mlx_whisper

        if not (model / "config.json").is_file() or not (model / "weights.npz").is_file():
            raise FileNotFoundError(f"Whisper model files are missing from {model}")
        while True:
            chunks = sorted(queue.glob("chunk-*.wav"))
            if not chunks:
                if (queue / "STOP").exists():
                    break
                time.sleep(0.2)
                continue
            chunk = chunks[0]
            index = int(chunk.stem.split("-")[-1])
            try:
                result = mlx_whisper.transcribe(
                    str(chunk),
                    path_or_hf_repo=str(model),
                    language="en",
                    verbose=None,
                    temperature=0.0,
                    condition_on_previous_text=False,
                    no_speech_threshold=0.5,
                    logprob_threshold=-1.5,
                    compression_ratio_threshold=1.8,
                )
                segments = [
                    segment for segment in result.get("segments", [])
                    if segment.get("text", "").strip()
                    and segment.get("no_speech_prob", 0.0) <= 0.5
                    and segment.get("avg_logprob", 0.0) >= -1.5
                ]
                text = " ".join(segment["text"].strip() for segment in segments)
                cue_matches = [
                    (match.group(0), segment)
                    for segment in result.get("segments", [])
                    if segment.get("no_speech_prob", 0.0) <= 0.65
                    for match in WAKE_PHRASE.finditer(segment.get("text", ""))
                ]
                cue_scores = [round(100 * math.exp(min(0.0, segment.get("avg_logprob", -1.5)))) for _, segment in cue_matches]
                cue_phrase = None
                if cue_matches:
                    matched_text = cue_matches[-1][0].lower()
                    cue_phrase = "OK, next problem" if matched_text.startswith("next") or "next" in matched_text else "OK, problem"
                payload = {
                    "index": index,
                    "text": text,
                    "no_speech": not bool(text),
                    "wake_phrase_confidence": max(cue_scores) if cue_scores else None,
                    "wake_phrase": cue_phrase,
                }
                destination = queue / f"result-{index:06d}.json"
                temporary = destination.with_suffix(".tmp")
                temporary.write_text(json.dumps(payload), encoding="utf-8")
                temporary.replace(destination)
            except Exception as error:
                destination = queue / f"result-{index:06d}.json"
                destination.write_text(json.dumps({"index": index, "error": str(error)}), encoding="utf-8")
            finally:
                chunk.unlink(missing_ok=True)
        return 0
    except Exception as error:
        (queue / "worker-error.txt").write_text(f"{type(error).__name__}: {error}", encoding="utf-8")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
