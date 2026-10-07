# Voice todo

Voice todo continuously listens while its modal is open. Gridline divides the microphone stream into short temporary audio chunks and sends them to one persistent local MLX Whisper worker. Speech stays out of Problem Notes until Whisper recognizes a wake phrase above the adjustable confidence threshold. Chunks are deleted after processing and are not kept as recordings. The latest editable Problem Notes draft is saved locally in Gridline preferences and restored when the app opens; **Clear saved note** removes that cached draft.

Say **“OK, problem”** to start the first bullet. Say **“OK, next problem”** or **“next problem”** to start another. The **End problem** button is a manual boundary; speech after it starts a new bullet. The transcript remains editable in the modal.

Voice todo ignores very quiet chunks before Whisper runs and filters low-confidence/no-speech segments to avoid Whisper filling silence with guessed phrases. The minus/plus controls adjust the shared threshold for both wake phrases from 20% to 90%; lower values make triggering easier. The displayed score estimates the Whisper segment's transcription confidence, not a separate word-level probability. If your voice is quiet, check that the live meter moves above the speech gate and speak closer to the selected microphone.

The worker uses `../resources/models/whisper-small-mlx/`, shared with Audio to text. Install the Python packages from `../audio_to_text/requirements.txt` into Gridline's skill_script Python package directory as described in `../audio_to_text/README.md`.
