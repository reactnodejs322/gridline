# General Agent Workflow

## Required root instructions

Near the top of the repository's root `AGENTS.md` (or `agents.md`), before the keyword table, include a `## Agent workflow contract` section containing this guidance, adapted to the target repository's docs path and existing conventions:

> For each feature, use this chain: **human words → keyword table → feature document → verified code paths**. This file is the short LLM entry point; general agent guidance and feature details for this project live in `./docs/`.
>
> Match the user's ordinary wording, personal terms, project vocabulary, abbreviations, and synonyms to the closest keyword row. If several rows match, start with the narrowest guide for the requested behavior. Read the full linked guide before inspecting code, then verify its code paths against the source.
>
> Before editing, record `git status --short`. After implementation and relevant checks, compare status and inspect the task diff, including new files. Update the feature guide's **Where this lives in code** section with verified paths. For a new feature guide, put that section immediately after its title, document confirmed behavior, and add a **Checkpoint**. Add or update the keyword row with useful human terms and aliases learned from the request.
>
> Do not automatically move human-authored notes into feature guides. If a changed or untracked note in `docs/` seems relevant, ask before incorporating it and leave it unchanged unless asked.

## Keyword table update gate

Update the root keyword table with new human terms and aliases only after the user confirms they are satisfied or says the task is complete. If the user is not satisfied, hold back those new aliases. Preserve existing useful aliases when updating a row. Put feature explanations, commands, troubleshooting, and implementation details in the linked feature guide; do not replace a keyword-table update with prose.

Use this row format:

```md
| [human phrase, alternate wording, project term](docs/actual_feature_name.md) | Human feature name |
```

For example, “the device keeps disconnecting” and “keep it alive” are aliases for an existing device-connection guide:

```md
| [device connection, tablet connection, USB debugging, wireless ADB, keeps disconnecting, keep it alive](docs/device_connection.md) | Device connection and recovery |
```

This example only demonstrates human-word aliases; use the target repository's real feature names and guide paths.

### GUARDRAIL Required format for agents.md updates

When asked to document something in `AGENTS.md`, remember wording, or add a feature, symptom, phrase, or lookup, update the **Keyword table of contents** after the user confirms satisfaction or completion. Until then, hold back new keyword aliases.

- Add useful human terms and aliases to the first column of the closest existing row.
- Create a new row only when the information belongs in a separate feature guide.
- Put feature explanations, commands, troubleshooting, and implementation details in the linked guide.
- Do not replace the keyword-table update with a paragraph, note, or special-case instruction.
- Do not add feature-specific prose outside the table unless the user explicitly asks for that format.

Before finishing a documentation change, inspect the diff and confirm the accepted request terms appear in the keyword table, the feature details live in the linked guide, and changed links resolve. A prose-only addition does not satisfy a request to update the table.

Preserve the target repository's existing instructions and any explicit root-file size limit. The keyword table must link each distinct feature or skill to its own document in the target project's docs location. Keep those documents flat except for the designated human-written-docs folder. Do not replace a project's existing required workflow; integrate it into the contract without duplicating it.

## Adapt to the active repository

This guide supplies the requested workflow; the active repository's complete `AGENTS.md` or `agents.md` supplies its project-specific rules. Read it fully and learn the project's architecture, safety limits, commands, verification steps, terminology, and existing documentation map before proposing or creating anything. Preserve and follow those rules while adding the required feature lookup and human-keyword navigation. Preserve any explicit root-file size limit already in the target instructions; do not invent one. Keep the added contract concise enough to fit, and verify the limit if one exists. Do not paste this setup guide, generic example paths, or another project's assumptions into the target repository. Keep a linked chapter map intact and separate from the keyword table; only change it when a chapter or destination changes. Use the repository's actual code paths and the user's exact project terms as aliases for each feature document.

**Keep target-project content isolated.** Only put instructions, app names, paths, commands, indexes, and components in the target repository's files when they belong to that repository and are verified there. Never copy names or maintenance instructions from the tool or source repository supplying this setup prompt. Before asking for approval, check the proposed content for such cross-project references and remove them.

## Feature-work instructions to include in the project's root guide

When creating or updating the target `AGENTS.md`, use the `## Agent workflow contract` above. Adapt it to preserve the repository's existing conventions and project-specific workflows; integrate any existing required-workflow paragraph instead of duplicating it.

Do not add project-specific setup instructions from this guide. Derive those from the target repository's complete instructions and preserve any existing task-specific steps.

## Starting point

At the start of every feature request, explicitly read the complete active repository's root `AGENTS.md` or `agents.md`; do not assume it was fully included in the conversation context. Extract the user's exact feature names, personal phrasing, project-specific terms, abbreviations, and shorthand; search those terms and semantic variants in the keyword table, then explicitly read the complete linked feature document before opening implementation files. If no row matches, trace the behavior from source, create or update a focused feature document and its keyword row before implementation, then update both after verification. Preserve new user-supplied terms as aliases on the row for the verified document; do not create duplicate docs for synonyms. Keep feature and skill documents directly inside `docs/`; the only subfolder exception is the designated human-written-docs folder, named by the project or user and otherwise called `human_written_docs/`.

## Core chain

Work through this chain for each requested feature:

**human words → keyword table → feature document → verified code paths → implementation → evidence → updated documentation**

The keyword table is a short navigation aid. The feature document explains behavior and links to the current implementation. Source code and reliable checks are evidence for what actually works; documentation can be out of date.

## Root instructions and feature documents

- Add the required root rule above at the top of the root instructions, before the keyword table. Preserve its exact workflow: map the request to a keyword row, read the complete linked document, verify listed code paths before editing, then update the feature document and keyword row after checks.
- Add one keyword-table row for each distinct feature or skill document under `docs/`; don't use a catch-all project overview as a substitute for feature docs, and don't link this setup guide from the project's table.
- During setup, use the complete root instructions and the features/workflows they point to (plus README project overview when present) to identify distinct documented areas. Create or update a focused doc and verified code map for each area; don't stop after writing a project summary.
- Use this table shape in the root instructions; replace the example terms and path with verified project features:

  ```md
  ## Keyword table of contents
  | Human terms and aliases | Feature or skill document |
  |---|---|
  | [login, auth, sign in](docs/authentication.md) | Authentication |
  ```

- Put focused feature and skill documents directly in the repository's existing `docs/` folder. Keep it flat except for the designated human-written-docs subfolder; do not create topic subfolders or move human-authored notes without approval. Each feature document must list verified implementation paths in `## Where this lives in code` immediately after its title.
- Give the keyword table useful aliases that match how a person asks about each feature. Link each row to its real document path, such as `docs/feature_name.md`; never copy example paths that do not exist in this repository.
- Treat the user's exact wording, personal feature names, project-specific vocabulary, abbreviations, and shorthand as first-class aliases. Match them by meaning to the verified feature document, then preserve new user-provided terms in that document's existing keyword row only after the user confirms satisfaction or completion; otherwise hold them back. Do not make duplicate documents for synonyms.
- Start each feature document with its title, then `## Where this lives in code` and verified relative source paths. Follow with behavior and a short `## Checkpoint` describing what was verified and what remains uncertain.
- Keep keyword rows focused on human terms and aliases; put implementation paths in the linked feature documents.

## Workflow setup approval

When this guide is invoked to create or reorganize repository instructions, use a proposal-only first pass. Read the complete root instruction file and relevant linked documents, inspect the source paths that the proposed feature documents will cite, and report the files and content you plan to change. Ask exactly **“Are you sure you want me to make these Markdown changes?”** and stop. Do not edit or create project Markdown until the user explicitly approves. After approval, make only the described changes and verify every changed relative link.

This is a setup prompt, not a project feature guide. Do not copy it into the project's `.codex/` folder or link it from the project's keyword table.

## How to handle a feature request

1. **Define the outcome.** Identify what should change and how success can be observed. Ask a question only when the missing answer could change the implementation.
2. **Record the starting state.** Run `git status --short` before editing. Note existing modified and untracked files so they are not mistaken for this task's work.
3. **Find the right feature document.** Match the user's words and aliases in the keyword table. Read the linked document from beginning to end before searching broadly; do not rely on a partial preview or previously loaded context.
4. **Check the map against the source.** Confirm that linked files and symbols still exist and fit the requested behavior. Treat stale documentation as a clue, not proof.
5. **Retrieve only relevant context.** Read the linked code and its direct dependencies. Expand the search when references, behavior, or verification show that more context is needed.
6. **Make the smallest complete change.** Keep the implementation aligned with the requested outcome and existing boundaries.
7. **Verify with evidence.** Use relevant checks or observable behavior. A retry should respond to a specific new finding, such as an error, failed check, stale link, or user correction. Do not repeat unguided self-review.
8. **Review the resulting changes.** Run `git status --short` again and inspect the relevant diffs. Include new untracked files, which may not appear in a regular diff. Separate this task's changes from the starting state.
9. **Update documentation in the same task.** Update every affected feature document with the current implementation, test, and configuration paths. Remove links to files that moved or were deleted.
10. **Update navigation after acceptance.** Once the user confirms they are satisfied or says the task is complete, add or adjust the keyword-table row with useful human terms and aliases learned from the request. If the user is not satisfied, hold back those new terms. Link the row to its feature document.
11. **Report accurately.** Say what changed and what evidence was checked. State anything that remains uncertain; do not claim a check was run when it was not.

## Feature document format

Every feature guide under `docs/` starts with its feature title, followed immediately by one `## Where this lives in code` section. Show the guide's location separately; that location line is not part of the guide contents. Replace each placeholder with an existing, verified path relative to the guide, including relevant implementation and test/configuration files; omit paths that do not exist or do not apply.

Example guide location: `docs/feature.md`

Example contents of `docs/feature.md`:

```md
# {Feature name}

## Where this lives in code

- [`{verified feature source path}`](../{verified feature source path})
- [`{verified related test or configuration path}`](../{verified related test or configuration path})
```

## Example: adding a new feature

Suppose a request says: “Let me export the report as CSV.”

1. Search the keyword table for `report`, `export`, or `csv`.
2. If an export document exists, read it and inspect the linked source. If no suitable document exists, find the relevant implementation and create a focused document.
3. Implement CSV export and run the relevant verification.
4. Compare the ending Git status and diffs with the starting status. Suppose the change touched `src/report/exporter.ts`, added `tests/report/exporter.test.ts`, and changed `config/reporting.yaml`.
5. Put those verified paths at the top of the feature document, describe the behavior, and update its checkpoint.
6. Add a keyword row such as:

   ```md
   | [report, export, csv](docs/report_export.md) | Report export |
   ```

If the task only changes an existing feature, update its existing document and table mapping rather than creating a near-duplicate document.

## Research basis and limits

These studies suggest workflow choices; they do not prove that this exact documentation structure improves results in every repository.

- Khatri, “Do Context Files Help Coding Agents? A Two-Agent Ablation Study on Real Repositories,” REALM 2026. Across 288 runs, 17 tasks, and three repositories, context files did not measurably improve correctness in the tested setup. This cautions against assuming that more instructions always help. [Paper](https://aclanthology.org/2026.realm-1.5/)
- Wu et al., “Repoformer: Selective Retrieval for Repository-Level Code Completion,” ICML 2024. Studies when repository context should be retrieved for code completion; this supports selective context gathering, with a different task from feature implementation. [Paper](https://proceedings.mlr.press/v235/wu24a.html)
- Xia et al., “Demystifying LLM-Based Software Engineering Agents,” FSE 2025. Studies a staged software-repair workflow involving localization, repair, and validation. The benchmark is software repair, not this exact workflow. [Paper](https://lingming.cs.illinois.edu/publications/fse2025.pdf)
- Bi et al., “Iterative Refinement of Project-Level Code Context for Precise Code Generation with Compiler Feedback,” Findings of ACL 2024. Combines project context with static-analysis and compiler feedback in its evaluated code-generation setting. [Paper](https://aclanthology.org/2024.findings-acl.138/)
- Huang et al., “Large Language Models Cannot Self-Correct Reasoning Yet,” ICLR 2024. Finds that unguided self-correction can fail or reduce performance on studied reasoning tasks; this motivates tying retries to new evidence. [Paper](https://proceedings.iclr.cc/paper_files/paper/2024/hash/8b4add8b0aa8749d80a34ca5d941c355-Abstract-Conference.html)
