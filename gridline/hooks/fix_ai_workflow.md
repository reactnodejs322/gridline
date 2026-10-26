# Prompt: Propose a Safe Agent-Workflow Cleanup

## Approval is required before editing

Do not change or create files immediately. First inspect the root `agents.md`/`AGENTS.md` and only the code paths it explicitly lists. Then tell the user what you propose to change in the Markdown files, what information you would move, and what you would preserve. Ask: **“Are you sure you want me to make these Markdown changes?”** Stop and wait. Make no edits unless the user explicitly approves.

Near the top of the repository's root `AGENTS.md` (or `agents.md`), before the keyword table, include a `## Agent workflow contract` section containing this guidance, adapted to the target repository's docs path and existing conventions:

> For each feature, use this chain: **human words → keyword table → feature document → verified code paths**. This file is the short LLM entry point; general agent guidance and feature details for this project live in `./docs/`.
>
> Match the user's ordinary wording, personal terms, project vocabulary, abbreviations, and synonyms to the closest keyword row. If several rows match, start with the narrowest guide for the requested behavior. Read the full linked guide before inspecting code, then verify its code paths against the source.
>
> Before editing, record `git status --short`. After implementation and relevant checks, compare status and inspect the task diff, including new files. Update the feature guide's **Where this lives in code** section with verified paths. For a new feature guide, put that section immediately after its title, document confirmed behavior, and add a **Checkpoint**. Add or update the keyword row with useful human terms and aliases learned from the request.
>
> Do not automatically move human-authored notes into feature guides. If a changed or untracked note in `docs/` seems relevant, ask before incorporating it and leave it unchanged unless asked.

The keyword table must link each distinct feature or skill to its own Markdown document in the target project's docs location. Keep feature documents flat except for the designated human-written-docs folder. Preserve all existing instructions and Markdown while adding this structure. Do not create or modify project `.codex/` files, create a duplicate docs folder, or move human-authored notes without separate approval.

**Preserve the existing linked chapter map exactly.** Do not rewrite, replace, reorder, shorten, or convert its chapter rows, section links, labels, or descriptions into keyword entries. The chapter map and the human-keyword table are separate navigation aids. Add a separate `## Keyword table of contents` with useful human terms, personal/project-specific wording, abbreviations, and aliases linked to the matching feature documents. Update the chapter map only if a chapter or its destination actually changes.

**Adapt the workflow to this repository.** Treat its complete existing `AGENTS.md`/`agents.md` as the source for project-specific architecture, safety constraints, terminology, commands, and documentation conventions. Preserve those rules and apply them when organizing the docs; do not replace them with generic examples or assume another project's layout. Add the requested feature lookup workflow alongside the repository's rules. Reuse and enrich an existing feature keyword table if it already serves that purpose; if its table is a chapter map or another linked navigation map, keep that map intact and add a distinct keyword table. Map the user's own project terms and aliases to the project's actual feature documents and verified code paths. Preserve any explicit root-file size limit already in the project instructions; do not invent one, and verify that the proposed result fits.

**Keep target-project content isolated.** Only retain or add instructions, app names, paths, commands, indexes, and components that belong to the target repository and are verified there. Never copy names or maintenance instructions from the tool or source repository supplying this setup prompt. If an existing target file contains such a cross-project reference, identify it as inaccurate in the proposal and ask approval before removing it. After approved edits, check that every remaining named app, path, and index belongs to the target repository.

## Feature-work instructions to include in the project's root guide

When updating the target `AGENTS.md`, use the `## Agent workflow contract` above. Adapt it to preserve the repository's existing conventions and project-specific workflows; integrate any existing required-workflow paragraph instead of duplicating it.

Do not copy project-specific setup instructions from another repository or from this guide. Derive them from the target repository's complete instructions and preserve existing task-specific steps.

Copy the prompt below into an LLM session opened on the repository you want to clean up.

---

## Prompt to give the LLM

You are helping simplify an overgrown agent-instructions file in this repository. The repository may already have active work. Your task is to reorganize documentation and instructions, not to change product code.

### Stage 1: inspect and propose; do not edit

1. Read the root `agents.md` or `AGENTS.md` from beginning to end. Record its project-specific architecture, safety rules, terms, commands, file organization, and documentation conventions.
2. Find the code paths explicitly listed in that file. Open those paths to identify what each one does. If a path refers to a source file and a directly related test is obvious, inspect that test only when needed to understand the behavior. Do not survey the whole repository or follow unrelated dependencies.
3. Use the inspected paths and the existing project instructions to decide which details belong in focused Markdown documents under the repository's documented docs location. Follow the project's stated folder conventions. Seed keyword aliases with the user's own phrasing, project-specific terms, abbreviations, and shorthand, and map each term to the correct existing or newly focused document. Do not create duplicate docs for synonyms. Add the required feature workflow without replacing project-specific instructions. Do not invent a line-count limit; preserve and follow any explicit limit in the target repository's instructions.
4. Treat any existing linked chapter map as protected content. Propose a separate keyword table for human search terms and aliases; do not fold it into the chapter map or edit that map unless a chapter or destination is changing.
5. Before changing anything, report:
   - the Markdown files you propose to create or change;
   - the code paths from `agents.md` you inspected and what each contributes;
   - which instructions you propose to keep at the root and which details to move;
   - any unclear or potentially lost requirement.
6. Ask the user: **“Are you sure you want me to make these Markdown changes?”** Then stop. Do not create directories, edit files, or make other changes while awaiting the answer.

### Stage 2: make only the approved changes

Continue only after the user explicitly approves the proposal.

- Record `git status --short` immediately before editing so current work is not overwritten or confused with your changes.
- Make only the approved Markdown changes. Do not edit source code, tests, scripts, configuration, or human-authored notes.
- Keep the repository's existing project-specific architecture, safety, command, terminology, and navigation rules. Add the requested workflow around them; do not replace them with generic guidance.
- Preserve the existing linked chapter map exactly. Keep it separate from the keyword table; edit it only when an approved chapter or destination change requires it.
- Put the required workflow rule at the top of the root instruction file, before the keyword table. Include the user's exact and project-specific terms as aliases on the corresponding feature row.
- In each feature document, put `## Where this lives in code` directly after the title. Add only code paths that you inspected and verified. Use links relative to that Markdown document.
- Put a `## Checkpoint` at the bottom to record what is documented or verified and what remains uncertain.
- Preserve important constraints. Move their explanations into docs and keep a short root link or instruction when agents need to find them.
- Do not transfer human-authored notes into feature docs unless the user separately asks.

Every feature guide under `docs/` starts with its feature title, followed immediately by one `## Where this lives in code` section. Show the guide's location separately; that location line is not part of the guide contents. Replace each placeholder with an existing, verified path relative to the guide, including relevant implementation and test/configuration files; omit paths that do not exist or do not apply.

Example guide location: `docs/feature.md`

Example contents of `docs/feature.md`:

```md
# {Feature name}

## Where this lives in code

- [`{verified feature source path}`](../{verified feature source path})
- [`{verified related test or configuration path}`](../{verified related test or configuration path})
```

Example keyword-table row:

```md
| [report, export, csv](docs/report_export.md) | Report export |
```

After editing, check the Markdown links you changed and confirm the required workflow rule is at the top before the keyword table. Compare `git status --short` with the starting state. Inspect your diff, including new files. Report what changed and what was not verified. Do not claim tests or other checks were run unless they were.

If the user does not approve, do not edit anything. You may answer questions about the proposal, then wait for approval before proceeding.

---
