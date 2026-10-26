# Skill scripts and model resources

## Where this lives in code

- [download_models.py](../skill_script/download_models.py)
- [audio_to_text.py](../skill_script/audio_to_text/audio_to_text.py)
- [voice_todo.py](../skill_script/voice_todo/voice_todo.py)
- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)

## Skill scripts and model resources

### Audio to text

- Skill folder: `skill_script/audio_to_text/`.
- Produces transcripts from selected audio or video files.
- Uses Whisper and, when enabled, speaker diarization.

### Voice todo

- Skill folder: `skill_script/voice_todo/`.
- Uses the shared Whisper model for live voice capture.
- Writes recognized speech into editable Problem Notes.

### Model locations and downloads

- Whisper folder: `skill_script/resources/models/whisper-small-mlx/`.
- Whisper weights: `skill_script/resources/models/whisper-small-mlx/weights.npz`.
- Speaker segmentation: `skill_script/resources/models/speaker-diarization/segmentation/model.onnx`.
- Speaker embeddings: `skill_script/resources/models/speaker-diarization/speaker-embedding/model.onnx`.
- Downloader: `skill_script/download_models.py`.
- Model binaries are ignored by Git; the downloader pins revisions and verifies SHA-256.
- Builds and new version copies download missing models into their own resource folder.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
