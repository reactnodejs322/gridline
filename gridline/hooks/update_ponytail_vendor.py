#!/usr/bin/env python3
"""Pull Ponytail upstream and refresh Gridline's vendored source snapshot."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


UPSTREAM = "https://github.com/DietrichGebert/ponytail.git"


class UpdateError(Exception):
    pass


def git(arguments: list[str], cwd: Path | None = None) -> str:
    environment = os.environ.copy()
    environment["GIT_TERMINAL_PROMPT"] = "0"
    environment["GIT_ASKPASS"] = "/usr/bin/true"
    try:
        result = subprocess.run(
            ["git", *arguments], cwd=cwd, env=environment,
            check=True, capture_output=True, text=True, timeout=300,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise UpdateError("Git could not update the Ponytail source; Gridline's vendored copy was left unchanged.") from error
    return result.stdout.strip()


def read_version(vendor: Path) -> dict[str, str]:
    try:
        data = json.loads((vendor / "VENDOR_VERSION").read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError
        return {key: str(data.get(key, "")) for key in ("version", "commit", "upstream")}
    except (OSError, ValueError):
        return {"version": "unknown", "commit": "unknown", "upstream": UPSTREAM}


def current_state(root: Path) -> dict[str, Any]:
    vendor = root / "hook_vendor" / "ponytail"
    state = read_version(vendor)
    return {"ok": True, "version": state["version"], "commit": state["commit"], "upstream": UPSTREAM}


def verify_root(root: Path) -> tuple[Path, Path]:
    root = root.expanduser().resolve(strict=True)
    vendor_parent = root / "hook_vendor"
    vendor = vendor_parent / "ponytail"
    if not (root / "gridline" / "Package.swift").is_file():
        raise UpdateError("This folder does not contain the Gridline source package; no files were changed.")
    return vendor_parent, vendor


def vendor_ready(vendor: Path) -> bool:
    return all((vendor / relative).is_file() for relative in (
        "VENDOR_VERSION", "hooks/ponytail-map.js", "LICENSE", "assets/logo-dark.png",
    ))


def refresh_gridline_template(upstream_repo: Path, template_path: Path) -> None:
    skill_path = upstream_repo / "skills" / "ponytail" / "SKILL.md"
    if not skill_path.is_file():
        raise UpdateError("The pulled Ponytail repository has no skills/ponytail/SKILL.md; the vendored copy was left unchanged.")
    source = skill_path.read_text(encoding="utf-8")
    if source.startswith("---\n"):
        _, _, source = source.partition("---\n")
        _, separator, source = source.partition("---\n")
        if not separator:
            raise UpdateError("Ponytail's skill front matter is malformed; the vendored copy was left unchanged.")
    body = source.rstrip()
    generated_map = "\n\n## Gridline project map\n\n<!-- ponytail-map:start -->\nThe project map is generated on Codex session start and after relevant source changes.\n<!-- ponytail-map:end -->\n"
    template_path.write_text(body + generated_map, encoding="utf-8")


def patch_map(stage: Path) -> None:
    map_path = stage / "hooks" / "ponytail-map.js"
    if not map_path.is_file():
        raise UpdateError("The pulled Ponytail repository has no hooks/ponytail-map.js; the vendored copy was left unchanged.")
    source = map_path.read_text(encoding="utf-8")
    skip_line = next((line for line in source.splitlines() if line.startswith("const SKIP_DIR = ")), None)
    if skip_line is None:
        raise UpdateError("Ponytail's map helper changed shape; Gridline's .codex exclusion could not be applied.")
    if r"\.codex" not in skip_line:
        updated = re.sub(r"\.git\|", r".git|\.codex|", skip_line, count=1)
        if updated == skip_line:
            raise UpdateError("Ponytail's map helper changed shape; Gridline's .codex exclusion could not be applied.")
        source = source.replace(skip_line, updated, 1)
    if "Gridline adaptation: exclude the project's local .codex hook files" not in source:
        lines = source.splitlines()
        insertion = 1 if lines and lines[0].startswith("#!") else 0
        lines.insert(insertion, "// Gridline adaptation: exclude the project's local .codex hook files from the map.")
        source = "\n".join(lines) + "\n"
    map_path.write_text(source, encoding="utf-8")


def update(root: Path, *, pull: bool = True) -> dict[str, Any]:
    vendor_parent, vendor = verify_root(root)
    vendor_parent.mkdir(parents=True, exist_ok=True)
    checkout = vendor_parent / ".ponytail-upstream"
    if checkout.exists():
        if not (checkout / ".git").exists():
            raise UpdateError("The local Ponytail update checkout is not a Git repository; no vendored files were changed.")
        origin = git(["remote", "get-url", "origin"], cwd=checkout)
        if origin.rstrip("/") not in {UPSTREAM.rstrip("/"), "git@github.com:DietrichGebert/ponytail.git"}:
            raise UpdateError("The local Ponytail update checkout has an unexpected origin; no vendored files were changed.")
        if pull:
            git(["pull", "--ff-only"], cwd=checkout)
    else:
        git(["clone", "--depth", "1", UPSTREAM, str(checkout)])

    package = json.loads((checkout / "package.json").read_text(encoding="utf-8"))
    version = str(package.get("version", "unknown"))
    commit = git(["rev-parse", "HEAD"], cwd=checkout)
    previous = read_version(vendor) if vendor_ready(vendor) else {"commit": "", "version": "unknown", "upstream": UPSTREAM}
    if previous["commit"] == commit:
        return {"ok": True, "version": version, "commit": commit, "changed": False, "message": "Ponytail source is already current."}

    with tempfile.TemporaryDirectory(prefix=".ponytail-stage-", dir=vendor_parent) as temporary:
        stage = Path(temporary) / "ponytail"
        shutil.copytree(checkout, stage, ignore=shutil.ignore_patterns(".git", ".DS_Store", "__pycache__", "node_modules"))
        patch_map(stage)
        (stage / "VENDOR_VERSION").write_text(
            json.dumps({"version": version, "commit": commit, "upstream": UPSTREAM}, indent=2) + "\n",
            encoding="utf-8",
        )

        template_temp = Path(temporary) / "ponytail.md.template"
        refresh_gridline_template(checkout, template_temp)

        backup = vendor_parent / ".ponytail-previous"
        if backup.exists():
            shutil.rmtree(backup)
        if vendor.exists():
            os.replace(vendor, backup)
        try:
            os.replace(stage, vendor)
        except OSError:
            if backup.exists():
                os.replace(backup, vendor)
            raise
        if backup.exists():
            shutil.rmtree(backup)
        os.replace(template_temp, root / "gridline" / "hooks" / "ponytail.md.template")

    return {"ok": True, "version": version, "commit": commit, "changed": True, "message": "Ponytail source was pulled and refreshed."}


def ensure(root: Path) -> dict[str, Any]:
    _, vendor = verify_root(root)
    if vendor_ready(vendor):
        return current_state(root)
    result = update(root, pull=False)
    result["message"] = "Ponytail source was cloned and prepared for Gridline." if result.get("changed") else result.get("message", "")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("inspect", "ensure", "update"))
    parser.add_argument("--repo-root", required=True)
    args = parser.parse_args()
    try:
        root = Path(args.repo_root).expanduser().resolve(strict=True)
        if args.action == "inspect":
            result = current_state(root)
        elif args.action == "ensure":
            result = ensure(root)
        else:
            result = update(root)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (UpdateError, OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "message": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
