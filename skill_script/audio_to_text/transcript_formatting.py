"""Simple transcript formatting for the fast, speaker-free mode."""

from typing import Any


def format_transcript_by_pauses(
    segments: list[dict[str, Any]],
    pause_seconds: float = 2.0,
) -> str:
    """Join adjacent Whisper segments and start a new paragraph after long pauses."""
    paragraphs: list[str] = []
    current_text: list[str] = []
    previous_end: float | None = None

    for segment in segments:
        text = segment.get("text", "").strip()
        if not text:
            continue
        start = float(segment.get("start", previous_end or 0.0))
        end = float(segment.get("end", start))
        if current_text and previous_end is not None and start - previous_end >= pause_seconds:
            paragraphs.append(" ".join(current_text))
            current_text = []
        current_text.append(text)
        previous_end = end

    if current_text:
        paragraphs.append(" ".join(current_text))
    return "\n\n".join(paragraphs)
