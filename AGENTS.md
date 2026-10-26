## Agent workflow contract

For each feature, use this chain: **human words → keyword table → feature document → verified code paths**. This file is the short LLM entry point; general agent guidance and feature details for this project live in `./docs/`.

Match the user's ordinary wording, personal terms, project vocabulary, abbreviations, and synonyms to the closest keyword row. If several rows match, start with the narrowest guide for the requested behavior. Read the full linked guide before inspecting code, then verify its code paths against the source.

Before editing, record `git status --short`. After implementation and relevant checks, compare status and inspect the task diff, including new files. Update the feature guide's **Where this lives in code** section with verified paths. For a new feature guide, put that section immediately after its title, document confirmed behavior, and add a **Checkpoint**. Add or update the keyword row with useful human terms and aliases learned from the request.

Do not automatically move human-authored notes into feature guides. If a changed or untracked note in `docs/` seems relevant, ask before incorporating it and leave it unchanged unless asked.

<!-- Each Markdown file in docs/ is a feature guide. The filename below is a generic example; use the actual feature name in the project. -->
Feature guide path: `docs/feature.md`

The path above is where the file is saved. The file contents start here:

# {Feature name}

## Where this lives in code

- [`{verified source path}`](../{verified source path})
- [`{verified test or configuration path}`](../{verified test or configuration path})

Replace each placeholder with a path that exists and has been verified. Use links relative to the feature guide and include only paths relevant to that feature.


Before changing code, read [Project rules and copy selection](docs/project-rules.md) for the target app copy, privacy, Accessibility IDs, model storage, and implementation boundaries. Read the [Gridline Debug index](gridline_debug/INDEX.md) before changing app behavior.

## Table of contents

Use the terms as people say them, including shorthand and aliases. Read the full linked document, then inspect its code paths. If a request spans features, read each matching document.

| Human terms and aliases | Feature document |
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
