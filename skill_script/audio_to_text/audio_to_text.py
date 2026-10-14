#!/usr/bin/env python3
"""Transcribe one audio or video file with the local MLX Whisper model."""

import sys
from pathlib import Path

import mlx_whisper.audio
import numpy as np

from speaker_diarization import diarize_transcript_segments
from transcript_formatting import format_transcript_by_pauses
try:
    from gridline_trace import stage as trace_stage
except ImportError:
    def trace_stage(*args, **kwargs) -> None:
        return None


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[3] not in {"speakers", "pauses"}:
        print("usage: audio_to_text.py INPUT_FILE OUTPUT_TEXT_FILE {speakers|pauses}", file=sys.stderr)
        return 2

    input_path, output_path = map(Path, sys.argv[1:3])
    mode = sys.argv[3]
    current_stage = "load_model"
    skill_folder = Path(__file__).resolve().parent
    skill_root = skill_folder.parent
    model_path = skill_root / "resources" / "models" / "whisper-small-mlx"
    try:
        trace_stage("audio_to_text", current_stage, "started")
        import mlx_whisper

        if not (model_path / "config.json").is_file() or not (model_path / "weights.npz").is_file():
            raise FileNotFoundError(f"Whisper model files are missing from {model_path}")

        current_stage = "load_audio"
        trace_stage("audio_to_text", current_stage, "started")
        audio = mlx_whisper.audio.load_audio(str(input_path), sr=16000)
        trace_stage("audio_to_text", current_stage, "completed")
        current_stage = "transcribe"
        trace_stage("audio_to_text", current_stage, "started")
        result = mlx_whisper.transcribe(
            audio,
            path_or_hf_repo=str(model_path),
            language="en",
            verbose=None,
        )
        trace_stage("audio_to_text", current_stage, "completed")
        if mode == "speakers":
            current_stage = "speaker_diarization"
            trace_stage("audio_to_text", current_stage, "started")
            transcript = diarize_transcript_segments(
                np.asarray(audio, dtype=np.float32),
                result.get("segments", []),
                skill_root / "resources" / "models" / "speaker-diarization",
            )
            trace_stage("audio_to_text", current_stage, "completed")
        else:
            current_stage = "format_pauses"
            trace_stage("audio_to_text", current_stage, "started")
            transcript = format_transcript_by_pauses(result.get("segments", []))
            trace_stage("audio_to_text", current_stage, "completed")
        if not transcript:
            transcript = result["text"].strip()
        current_stage = "write_transcript"
        trace_stage("audio_to_text", current_stage, "started")
        output_path.write_text(transcript + "\n", encoding="utf-8")
        trace_stage("audio_to_text", current_stage, "completed", segments=len(result.get("segments", [])))
        return 0
    except Exception as error:
        trace_stage("audio_to_text", current_stage, "failed", error)
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
