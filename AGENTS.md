## Agent workflow contract

For each feature, use this chain: **human words → keyword table → feature document → verified code paths**. This file is the short LLM entry point; general agent guidance and feature details live in `./docs/`.

^ update the keyword table when a human word is completed or the human is satisfied.. IF THE HUMAN IS SATISFIED UPDATE IT IF NOT  HOLD BACK

### Find the relevant guide

Match the user's ordinary wording, personal terms, project vocabulary, abbreviations, and synonyms to the closest keyword row. If several rows match, start with the narrowest guide for the requested behavior.

Read the full linked guide before inspecting code, then verify its code paths against the source. Search more broadly only when the table and linked guide do not provide enough information.

### GUARDRAIL Required format for agents.md updates

When asked to “document this in agents.md,” “remember this wording,” or add a feature, symptom, phrase, or lookup, update the **Keyword table of contents**.

- Add useful human terms and aliases to the first column of the closest existing row.
- Create a new row only when the information belongs in a separate feature guide.
- Put feature explanations, commands, troubleshooting, and implementation details in the linked guide.
- Do not substitute a paragraph, note, or special-case instruction for a keyword-table update.
- Do not add feature-specific paragraphs outside the table unless the user explicitly requests that format.
- Keep general workflow rules in this contract.

Use this row format:

```md
| [human phrase, alternate wording, project term](docs/actual_feature_name.md) | Human feature name |
```

For example, “the Inspector keeps disconnecting” and “keeping it alive” belong as aliases in the existing connection row:

```md
| [{human words}  {human word} {everything here is a human word sample}Android device connection, tablet connection, ADB, USB debugging, wireless ADB, keeps disconnecting, keeping it alive, keep alive](docs/android_device_connection.md) | Android tablet connection, ADB setup, and keep-alive recovery |
```

Preserve existing useful aliases when updating a row. The examples above illustrate the format; the actual entries belong in the keyword table.

Before finishing, inspect the diff and confirm that the requested terms were added inside the keyword table. A prose-only addition does not satisfy this request.

### Implement and verify

Before editing, record `git status --short`.

After implementation and relevant checks, compare status and inspect the task diff, including new files. Distinguish existing changes from this task's changes.

Update the owning feature guide's **Where this lives in code** section when the task adds, changes, moves, or removes relevant implementation, test, or configuration paths. Include only verified paths relevant to that feature.

For a new feature guide:

- Use a descriptive filename under `docs/`.
- Put **Where this lives in code** immediately after the title.
- Document confirmed behavior and add a **Checkpoint** stating what was verified and what remains unverified.
- Add a keyword-table row linking to the guide.

Before finishing a documentation change, verify that:

- Requested search terms appear inside the keyword table.
- Feature-specific details live in the linked guide.
- Links resolve and code paths have been verified.
- No redundant feature-specific paragraph was added to this entry point.

### Preserve human-authored notes

Do not automatically move human-authored notes into feature guides. If a changed or untracked note in `docs/` seems relevant, ask before incorporating it and leave it unchanged unless asked.

### Feature guide template

Save the guide as `docs/actual_feature_name.md`. Replace the placeholders below; include only relevant paths that exist and have been verified. Links are relative to the guide.

```md
# {Feature name}

## Where this lives in code

- [Implementation](../{verified source path})
- [Tests or configuration](../{verified test or configuration path})

## Behavior

{Confirmed behavior and relevant operating instructions.}

## Checkpoint

{Evidence checked, verification results, and anything still unverified.}

Before changing code, read [Project rules and copy selection](docs/project-rules.md) for the target app copy, privacy, Accessibility IDs, model storage, and implementation boundaries. Read the [Gridline Debug index](gridline_debug/INDEX.md) before changing app behavior.

## Table of contents

Use the terms as people say them, including shorthand and aliases. Read the full linked document, then inspect its code paths. If a request spans features, read each matching document.

| Keyword table of contents | Feature document |
| --- | --- |
| work group, workgroup, group, project tile, current product behavior, terminal, Codex session, folder, label, rename, zoom, resize, sidebar, broadcast prompt, cd, pwd, ls, directory command | [Workspace and terminals](docs/workspace.md) |
| skin, template, main template, template architecture, UI skins, appearance, palette, dropdown, popover, template selector | [Templates and dropdowns](docs/templates.md) |
| usage, provider usage, terminal usage, reusable logic, bundled tools, shared tools, tokens, IN/OUT, cost estimate, ChatGPT meter, Claude meter, pricing, unpriced model | [Reusable logic and bundled tools](docs/shared-services.md) |
| project hooks, Ponytail, Ponytail source, update vendor, compaction, PreCompact, PostCompact, Rust Skill, System Design | [Project hooks](docs/project-hooks.md) |
| AI workflow, agent workflow, fix AI workflow, create workflow, keyword table, human keywords, docs cleanup | [AI workflow](docs/ai-workflow.md) |
| Gridline Debug, inspector permissions, inspector diagnostics, Accessibility, hover, selected element, current logs, full log output, timeline, report, source lookup, Input Monitoring, Python trace | [Gridline Debug](docs/gridline-debug.md) |
| audio transcription, audio to text, Whisper, speaker labels, transcript, pause paragraphs | [Audio to text](docs/audio-to-text.md) |
| Voice todo, voice notes, Problem Notes, wake phrase, microphone capture | [Voice todo](docs/voice-todo.md) |
| skill scripts, skill menu, local processing, model resources, model locations, model download, Whisper model, diarization model, checksum, pinned revision | [Skill scripts and model resources](docs/skills-and-models.md) |
| start main app, build, hot reload, launch, restart, build error, shared stop, diagnostic commands, create version, debug version, stop version, version lifecycle, version copy, isolated version, Version 1 | [Build and version lifecycle](docs/build-and-versions.md) |
| app copy, copy selection, main vs version, project layout, privacy, accessibility IDs, implementation rules | [Project rules and copy selection](docs/project-rules.md) |
| find a source file, search the code, Grep guide, grep, source map, stable identifiers, code path, accessibility identifier | [Code navigation](docs/code-navigation.md) |
| roadmap, product direction, future work, handoff, unshipped ideas | [Product direction and handoff](docs/product-direction.md) |
| Swift code hygiene, Swift file map, Package.swift, code style, LLM navigation | [Swift code hygiene and LLM navigation](docs/swift-navigation.md) |
