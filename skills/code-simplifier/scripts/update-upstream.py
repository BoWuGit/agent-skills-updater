#!/usr/bin/env python3
"""Check Anthropic's code-simplifier and sync this cross-harness adaptation."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
SKILL_DIR = Path(__file__).resolve().parent.parent
DATA_HOME = Path(
    os.environ.get(
        "AGENT_SKILLS_DATA_HOME", HOME / ".local/share/agent-skills-updater"
    )
)
UPSTREAM_REF = os.environ.get("CODE_SIMPLIFIER_UPSTREAM_REF", "main")
UPSTREAM_RAW_URL = os.environ.get(
    "CODE_SIMPLIFIER_UPSTREAM_RAW_URL",
    "https://raw.githubusercontent.com/anthropics/claude-plugins-official/"
    f"{UPSTREAM_REF}/plugins/code-simplifier/agents/code-simplifier.md",
)
UPSTREAM_CACHE = DATA_HOME / "sources/code-simplifier-upstream.md"
SNAPSHOT_FILE = SKILL_DIR / "references/upstream-code-simplifier.md"
STATE_FILE = SKILL_DIR / "references/upstream-state.json"


def refresh_upstream() -> None:
    request = urllib.request.Request(
        UPSTREAM_RAW_URL,
        headers={"User-Agent": "agent-skills-updater"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        content = response.read().decode("utf-8")

    if not content.startswith("---\n") or "name: code-simplifier\n" not in content:
        raise ValueError("official code-simplifier failed frontmatter validation")

    UPSTREAM_CACHE.parent.mkdir(parents=True, exist_ok=True)
    temporary = UPSTREAM_CACHE.with_suffix(".tmp")
    temporary.write_text(content)
    temporary.replace(UPSTREAM_CACHE)


def digest(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()


def skill_targets() -> list[Path]:
    configured = os.environ.get("AGENT_SKILLS_TARGETS")
    if configured:
        return [Path(path) for path in configured.split(":") if path]

    targets = [HOME / ".agents/skills"]
    candidates = (
        (HOME / ".claude", HOME / ".claude/skills"),
        (HOME / ".codex", HOME / ".codex/skills"),
        (HOME / ".config/agents", HOME / ".config/agents/skills"),
        (HOME / ".pi/agent", HOME / ".pi/agent/skills"),
        (HOME / ".cursor", HOME / ".cursor/skills"),
    )
    targets.extend(target for parent, target in candidates if parent.is_dir())
    return targets


def sync_harness_links() -> None:
    force = os.environ.get("AGENT_SKILLS_FORCE") == "1"
    for target_root in skill_targets():
        target_root.mkdir(parents=True, exist_ok=True)
        destination = target_root / "code-simplifier"

        if destination.is_symlink():
            existing = destination.resolve(strict=False)
            if existing == SKILL_DIR or DATA_HOME in existing.parents or force:
                destination.unlink()
            else:
                print(f"skip unmanaged symlink: {destination} -> {existing}", file=sys.stderr)
                continue
        elif destination.exists():
            if not force:
                print(f"skip existing non-symlink: {destination}", file=sys.stderr)
                continue
            if destination.is_dir():
                shutil.rmtree(destination)
            else:
                destination.unlink()

        destination.symlink_to(SKILL_DIR, target_is_directory=True)
        print(f"  code-simplifier -> {destination}")


def record_upstream(content: str) -> None:
    SNAPSHOT_FILE.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT_FILE.write_text(content)
    state = {
        "source": UPSTREAM_RAW_URL,
        "ref": UPSTREAM_REF,
        "sha256": digest(content),
    }
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n")


def show_upstream_diff(previous: str, current: str) -> None:
    diff = difflib.unified_diff(
        previous.splitlines(keepends=True),
        current.splitlines(keepends=True),
        fromfile="previous upstream",
        tofile="current upstream",
    )
    sys.stdout.writelines(diff)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect official code-simplifier changes without overwriting local adaptations."
    )
    parser.add_argument(
        "--acknowledge",
        action="store_true",
        help="Record the official version after reviewing/merging its changes.",
    )
    parser.add_argument(
        "--no-pull",
        action="store_true",
        help="Inspect the cached upstream file without downloading it.",
    )
    parser.add_argument(
        "--sync-only",
        action="store_true",
        help="Only link the bundled adaptation into detected harnesses.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.sync_only:
        sync_harness_links()
        return 0

    if not args.no_pull:
        refresh_upstream()
    if not UPSTREAM_CACHE.is_file():
        raise FileNotFoundError(f"upstream cache does not exist: {UPSTREAM_CACHE}")

    current = UPSTREAM_CACHE.read_text()
    previous = SNAPSHOT_FILE.read_text() if SNAPSHOT_FILE.exists() else ""

    if args.acknowledge:
        record_upstream(current)
        sync_harness_links()
        print(f"Recorded reviewed upstream ref {UPSTREAM_REF}.")
        return 0

    if current != previous:
        print("Official code-simplifier changed; the adaptation was not overwritten.\n")
        show_upstream_diff(previous, current)
        print(
            "\nReview and merge useful changes into SKILL.md, then run:\n"
            f"  {Path(__file__)} --no-pull --acknowledge"
        )
        return 2

    sync_harness_links()
    print(f"code-simplifier is current ({digest(current)[:12]}).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"update failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
