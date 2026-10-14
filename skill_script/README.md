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
    └── models/              # shared, locally downloaded model assets; binaries are ignored by Git
        ├── whisper-small-mlx/
        │   ├── config.json
        │   └── weights.npz          # shared by Audio to text and Voice todo
        └── speaker-diarization/
            ├── segmentation/model.onnx
            └── speaker-embedding/model.onnx
```

Keep each selectable script and its helpers together in one named folder. Put shared model files in `resources/models/`. Run `python3 skill_script/download_models.py` to fetch and verify the pinned models there. The Gridline build and version creation flows run this setup automatically and print **“Downloading models for resources”** when files are missing. Model binaries for every skill stay out of Git; each version downloads into its own `skill_script/resources/models/` folder. Audio to text and Voice todo share Whisper; Audio to text also uses the two speaker diarization models listed above.

Swift-launched skill processes use `gridline/Sources/Gridline/DebugEvents.swift` to record launch and exit stages. Python stages use the shared `gridline/runtime/gridline_trace.py` helper. These traces are forwarded to Gridline Debug only while the paired inspector is open; log stage names, result status, safe error types, and numeric counts only, never audio-derived text or transcripts.
