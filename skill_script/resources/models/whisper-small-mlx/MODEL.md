# Local transcription model

This folder contains the MLX converted Whisper Small model used by
`../../../audio_to_text/audio_to_text.py`. The script resolves `config.json` and `weights.npz`
relative to its own location, so the same folder works in the repository and
inside Gridline.app resources.

The model is downloaded from `mlx-community/whisper-small-mlx` at the pinned
Hugging Face revision `eb52dbc58f50f19eb8c87b54b7c621633c67b7e0`. The setup
script verifies the expected SHA-256 before saving it. It does not follow a
moving `main` or `latest` model version.

The model is stored locally and selected recordings are processed on this Mac.
