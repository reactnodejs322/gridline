"""Local speaker diarization and readable speaker-turn transcript formatting."""

from pathlib import Path
from typing import Any


def diarize_transcript_segments(
    audio_samples: Any,
    transcript_segments: list[dict[str, Any]],
    model_root: Path,
) -> str:
    """Assign each Whisper segment to its best-overlapping speaker and group turns."""
    import numpy as np
    import sherpa_onnx

    segmentation_model = model_root / "segmentation" / "model.onnx"
    embedding_model = model_root / "speaker-embedding" / "model.onnx"
    if not segmentation_model.is_file() or not embedding_model.is_file():
        raise FileNotFoundError(f"Local speaker model files are missing from {model_root}")

    diarization_config = sherpa_onnx.OfflineSpeakerDiarizationConfig(
        embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(
            model=str(embedding_model),
            num_threads=4,
        ),
        segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
            pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(
                model=str(segmentation_model),
                window_shift_ratio=0.25,
            ),
            num_threads=4,
        ),
        clustering=sherpa_onnx.FastClusteringConfig(
            num_clusters=-1,
            threshold=0.9,
        ),
        min_duration_on=0.3,
        min_duration_off=0.5,
    )
    if not diarization_config.validate():
        raise RuntimeError("The local speaker diarization model configuration is invalid")

    diarizer = sherpa_onnx.OfflineSpeakerDiarization(diarization_config)
    speaker_segments = diarizer.process(
        np.asarray(audio_samples, dtype=np.float32)
    ).sort_by_start_time()

    speaker_names: dict[int, str] = {}
    turns: list[tuple[int, list[str]]] = []
    previous_speaker: int | None = None

    for segment in transcript_segments:
        text = segment.get("text", "").strip()
        if not text:
            continue
        start = float(segment.get("start", 0.0))
        end = float(segment.get("end", start))
        speaker = _speaker_for_interval(start, end, speaker_segments)
        if speaker is None:
            speaker = previous_speaker if previous_speaker is not None else 0
        previous_speaker = speaker

        if speaker not in speaker_names:
            speaker_names[speaker] = f"Person {len(speaker_names) + 1}"
        if turns and turns[-1][0] == speaker:
            turns[-1][1].append(text)
        else:
            turns.append((speaker, [text]))

    return "\n\n".join(
        f"{speaker_names[speaker]}: {' '.join(text_parts)}"
        for speaker, text_parts in turns
    )


def _speaker_for_interval(start: float, end: float, speaker_segments: Any) -> int | None:
    """Choose the diarized speaker with the most time overlapping a Whisper segment."""
    if end <= start:
        end = start + 0.1

    overlap_by_speaker: dict[int, float] = {}
    nearest: tuple[float, int] | None = None
    midpoint = (start + end) / 2
    for diarized in speaker_segments:
        overlap = max(0.0, min(end, diarized.end) - max(start, diarized.start))
        if overlap > 0:
            overlap_by_speaker[diarized.speaker] = (
                overlap_by_speaker.get(diarized.speaker, 0.0) + overlap
            )

        distance = max(diarized.start - midpoint, 0.0, midpoint - diarized.end)
        if nearest is None or distance < nearest[0]:
            nearest = (distance, diarized.speaker)

    if overlap_by_speaker:
        return max(overlap_by_speaker, key=overlap_by_speaker.get)
    if nearest is not None and nearest[0] <= 0.75:
        return nearest[1]
    return None
