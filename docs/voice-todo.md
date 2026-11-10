# Voice todo

## Where this lives in code

- [voice_todo.py](../skill_script/voice_todo/voice_todo.py)
- [VoiceTodo.swift](../gridline/Sources/Gridline/VoiceTodo.swift)
- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)
- [Gridline stop script](../stop.sh)

## Behavior

- Skill folder: `skill_script/voice_todo/`.
- Uses the shared Whisper model for live voice capture.
- Writes recognized speech into editable Problem Notes.
- `./stop.sh` also finds and stops detached workers for each Gridline app copy, including workers reparented to PID 1.

Read the [full feature guide](../skill_script/voice_todo/README.md) for processing details and resources.

## Checkpoint

- [x] The root guide summary and owning code paths are mapped.
- [ ] Recheck this page when the feature guide or implementation changes.
