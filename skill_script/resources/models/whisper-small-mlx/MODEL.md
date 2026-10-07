# Local transcription model

This folder contains the MLX converted Whisper Small model used by
`../audio_to_text.py`. The script resolves `config.json` and `weights.npz`
relative to its own location, so the same folder works in the repository and
inside Gridline.app resources.

The model is stored locally and selected recordings are processed on this Mac.
