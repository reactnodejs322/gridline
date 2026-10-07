# Skill script layout

```text
skill_script/
├── README.md
├── audio_to_text/          # one selectable skill in Gridline's skill_script menu
│   ├── audio_to_text.py
│   ├── speaker_diarization.py
│   ├── transcript_formatting.py
│   └── requirements.txt
├── voice_todo/              # continuous local voice capture into editable problem bullets
│   ├── voice_todo.py        # persistent chunk worker using the shared Whisper model
│   └── README.md
└── resources/
    └── models/              # shared, bundled model assets
        ├── whisper-small-mlx/
        └── speaker-diarization/
```

Keep each selectable script and its helpers together in one named folder. Put shared model files in `resources/`. Gridline exposes Audio to text and Voice todo; both use the shared `whisper-small-mlx` model. Voice todo transcribes short temporary chunks continuously into its editable modal and deletes chunks after processing.
