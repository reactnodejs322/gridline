# Audio to text

This skill offers two local output modes. **Separate speakers** runs diarization and writes one paragraph per speaker turn with `Person 1`, `Person 2`, and so on. **Transcript only** skips diarization and starts a new paragraph after a pause of about two seconds. Copied and saved text keeps the selected formatting.

Speaker analysis uses a 0.25 window shift, four CPU threads, and a conservative 0.9 clustering threshold to avoid splitting one voice into many labels. The number of speakers remains automatically detected.

## Files and resources

- `audio_to_text/audio_to_text.py` coordinates the transcription modes.
- `audio_to_text/speaker_diarization.py` assigns Whisper time ranges to diarized speakers.
- `audio_to_text/transcript_formatting.py` groups transcript segments across pauses.
- `../resources/models/whisper-small-mlx/` contains the locally downloaded MLX Whisper model.
- `../resources/models/speaker-diarization/segmentation/` contains the pyannote segmentation model converted for sherpa-onnx.
- `../resources/models/speaker-diarization/speaker-embedding/` contains the 3D-Speaker ERes2Net speaker embedding model.

The model binaries are ignored by Git. Gridline's build setup downloads and verifies missing models into `../resources/models/`; run `python3 skill_script/download_models.py` manually if needed. The diarization assets are MIT licensed for segmentation and Apache-2.0 licensed for the speaker embedding model; each model directory includes its license. Their upstream project and model sources are listed in `../resources/models/speaker-diarization/MODELS.md`.

## Python packages

Install the packages into Gridline's local skill-script package folder:

```sh
python3 -m pip install --upgrade --target "$HOME/Library/Application Support/Gridline/skill_script/python-packages" -r skill_script/audio_to_text/requirements.txt
```

Gridline sets `PYTHONPATH` to this folder when it launches the script. Model inference does not need a Hugging Face token or network access.
