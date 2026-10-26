#!/usr/bin/env python3
"""Install or inspect Gridline's project-local Codex hooks."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


OWNED_DIRECTORY_MARKER = ".gridline-managed"


class InstallError(Exception):
    pass


def read_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"hooks": {}}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise InstallError("Could not read .codex/hooks.json; it was left unchanged.") from error
    if not isinstance(value, dict) or ("hooks" in value and not isinstance(value["hooks"], dict)):
        raise InstallError(".codex/hooks.json has an unsupported shape; it was left unchanged.")
    value.setdefault("hooks", {})
    return value


def atomic_write(path: Path, content: bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(descriptor, mode)
        with os.fdopen(descriptor, "wb") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def prepare_managed_directory(directory: Path) -> None:
    marker = directory / OWNED_DIRECTORY_MARKER
    if directory.exists() and not marker.exists():
        raise InstallError(".codex/hooks/gridline already exists and is not marked as Gridline-managed; no files were replaced.")
    directory.mkdir(parents=True, exist_ok=True)
    if not marker.exists():
        atomic_write(marker, b"Managed by Gridline. Only files in this folder are Gridline-owned.\n")


def copy_managed(source: Path, destination: Path, executable: bool = False) -> None:
    if not source.is_file():
        raise InstallError(f"Gridline hook resource is missing: {source.name}")
    atomic_write(destination, source.read_bytes(), 0o700 if executable else 0o600)


def command_contains(handler: Any, basename: str) -> bool:
    if not isinstance(handler, dict):
        return False
    command = handler.get("command")
    return isinstance(command, str) and basename in command


def remove_owned(hooks: dict[str, Any], event: str, basenames: set[str]) -> bool:
    groups = hooks.get(event)
    if not isinstance(groups, list):
        return False
    changed = False
    kept_groups = []
    for group in groups:
        if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
            kept_groups.append(group)
            continue
        kept_handlers = [handler for handler in group["hooks"]
                         if not any(command_contains(handler, name) for name in basenames)]
        if len(kept_handlers) != len(group["hooks"]):
            changed = True
        if kept_handlers:
            updated = dict(group)
            updated["hooks"] = kept_handlers
            kept_groups.append(updated)
        else:
            changed = True
    if kept_groups:
        hooks[event] = kept_groups
    else:
        hooks.pop(event, None)
    return changed


def append_handler(hooks: dict[str, Any], event: str, group: dict[str, Any]) -> None:
    groups = hooks.setdefault(event, [])
    if not isinstance(groups, list):
        raise InstallError(f"Hook config entry {event} is not a list; it was left unchanged.")
    groups.append(group)


def hook_group(command: str, matcher: str | None = None, status: str | None = None) -> dict[str, Any]:
    handler: dict[str, Any] = {"type": "command", "command": command, "timeout": 10}
    if status:
        handler["statusMessage"] = status
    group: dict[str, Any] = {"hooks": [handler]}
    if matcher:
        group["matcher"] = matcher
    return group


def configure_ponytail(hooks: dict[str, Any], script: Path) -> None:
    for event in ("SessionStart", "UserPromptSubmit", "PostToolUse"):
        remove_owned(hooks, event, {"gridline/ponytail_context.cjs"})
    command = f"node {shlex.quote(str(script))}"
    append_handler(hooks, "SessionStart", hook_group(
        f"{command} session-start", "startup|resume|clear|compact", "Loading Ponytail project context"
    ))
    append_handler(hooks, "UserPromptSubmit", hook_group(f"{command} prompt-submit"))
    append_handler(hooks, "PostToolUse", hook_group(
        f"{command} post-tool", "Bash|apply_patch", "Refreshing Ponytail project map"
    ))


def configure_compactions(hooks: dict[str, Any], script: Path, enabled: bool) -> None:
    for event in ("PreCompact", "PostCompact"):
        remove_owned(hooks, event, {"gridline_codex_hook.py"})
    if not enabled:
        return
    command = f"python3 {shlex.quote(str(script))}"
    append_handler(hooks, "PreCompact", hook_group(f"{command} compact", "manual|auto"))
    append_handler(hooks, "PostCompact", hook_group(f"{command} compact", "manual|auto"))


def save_config(path: Path, value: dict[str, Any]) -> None:
    atomic_write(path, (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))


def compact_enabled(hooks: dict[str, Any]) -> bool:
    for event in ("PreCompact", "PostCompact"):
        for group in hooks.get(event, []) if isinstance(hooks.get(event, []), list) else []:
            if isinstance(group, dict):
                for handler in group.get("hooks", []):
                    if command_contains(handler, "gridline_codex_hook.py"):
                        return True
    return False


def ponytail_enabled(hooks: dict[str, Any]) -> bool:
    for event in ("SessionStart", "UserPromptSubmit", "PostToolUse"):
        for group in hooks.get(event, []) if isinstance(hooks.get(event, []), list) else []:
            if isinstance(group, dict):
                for handler in group.get("hooks", []):
                    if command_contains(handler, "gridline/ponytail_context.cjs"):
                        return True
    return False


def install(args: argparse.Namespace) -> dict[str, Any]:
    terminal_directory = Path(args.project_root).expanduser().resolve(strict=True)
    if not terminal_directory.is_dir():
        raise InstallError("The selected terminal folder is not a directory.")
    project = terminal_directory
    try:
        git_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], cwd=terminal_directory,
            check=True, capture_output=True, text=True, timeout=3,
        ).stdout.strip()
        if git_root:
            project = Path(git_root).resolve(strict=True)
    except (OSError, subprocess.SubprocessError):
        pass
    resource = Path(args.resource_root).resolve(strict=True)
    if args.action == "install-ai-workflow":
        guides = (resource / "agent_workflow.md", resource / "fix_ai_workflow.md")
        docs = project / "docs"
        doc = project / "doc"
        managed_marker = project / ".codex" / ".gridline-agent-workflow-docs"
        if any(not source.is_file() for source in guides):
            raise InstallError("A bundled AI workflow guide is missing.")

        instruction_file = next((path for path in (project / "AGENTS.md", project / "agents.md") if path.exists()), None)
        if instruction_file is not None and not instruction_file.is_file():
            raise InstallError("The root AGENTS.md path is not a file; no files were changed.")
        instruction_file_name = instruction_file.name if instruction_file else "AGENTS.md"

        docs_conflict = doc.exists() or (docs.exists() and not managed_marker.is_file())
        return {
            "ok": not docs_conflict,
            "projectPath": str(project),
            "aiWorkflowGuidesAvailable": True,
            "agentInstructionsFileExists": instruction_file is not None,
            "agentInstructionsFileName": instruction_file_name,
            "docsFolderConflict": docs_conflict,
            "message": "Error: an existing doc folder was found." if docs_conflict else "AI workflow guides are available in Gridline.",
        }

    codex_dir = project / ".codex"
    hooks_dir = codex_dir / "hooks"
    managed_dir = hooks_dir / "gridline"
    config_path = codex_dir / "hooks.json"
    config = read_config(config_path)
    hooks = config["hooks"]

    if args.action == "inspect":
        return {
            "ok": True,
            "projectPath": str(project),
            "ponytailInstalled": ponytail_enabled(hooks),
            "compactionLoggingEnabled": compact_enabled(hooks),
            "ponytailFileExists": (codex_dir / "ponytail.md").is_file(),
        }

    wants_ponytail = args.action in {"install-ponytail", "install-all"}
    wants_compactions = args.action in {"enable-compactions", "install-all"}
    disables_compactions = args.action == "disable-compactions"
    if args.action not in {"install-ponytail", "enable-compactions", "disable-compactions", "install-all"}:
        raise InstallError("Unknown hook installer action.")

    touched_events = []
    if wants_ponytail:
        touched_events.extend(("SessionStart", "UserPromptSubmit", "PostToolUse"))
    if wants_compactions or disables_compactions:
        touched_events.extend(("PreCompact", "PostCompact"))
    for event in touched_events:
        if event in hooks and not isinstance(hooks[event], list):
            raise InstallError(f"Hook config entry {event} is not a list; no project files were changed.")

    prepare_managed_directory(managed_dir)
    if wants_ponytail:
        copy_managed(resource / "ponytail_context.cjs", managed_dir / "ponytail_context.cjs", executable=True)
        copy_managed(resource / "ponytail-map.js", managed_dir / "ponytail-map.js")
        copy_managed(resource / "ponytail-LICENSE", managed_dir / "ponytail-LICENSE")
        context = codex_dir / "ponytail.md"
        if not context.exists():
            copy_managed(resource / "ponytail.md.template", context)
        configure_ponytail(hooks, managed_dir / "ponytail_context.cjs")
    if wants_compactions:
        copy_managed(resource / "gridline_codex_hook.py", managed_dir / "gridline_codex_hook.py", executable=True)
        configure_compactions(hooks, managed_dir / "gridline_codex_hook.py", True)
    if disables_compactions:
        configure_compactions(hooks, managed_dir / "gridline_codex_hook.py", False)

    save_config(config_path, config)
    return {
        "ok": True,
        "projectPath": str(project),
        "terminalPath": str(terminal_directory),
        "ponytailInstalled": ponytail_enabled(hooks),
        "compactionLoggingEnabled": compact_enabled(hooks),
        "ponytailFileExists": (codex_dir / "ponytail.md").is_file(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("inspect", "install-ponytail", "enable-compactions", "disable-compactions", "install-all", "install-ai-workflow"))
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--resource-root", required=True)
    args = parser.parse_args()
    try:
        result = install(args)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (InstallError, OSError) as error:
        print(json.dumps({"ok": False, "message": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
