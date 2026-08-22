from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).parents[1] / "scripts/update-upstream.py"
SPEC = importlib.util.spec_from_file_location("code_simplifier_updater", SCRIPT_PATH)
assert SPEC and SPEC.loader
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class SkillTargetsTests(unittest.TestCase):
    def test_explicit_targets_are_respected(self) -> None:
        with mock.patch.dict(os.environ, {"AGENT_SKILLS_TARGETS": "/one:/two"}):
            self.assertEqual(updater.skill_targets(), [Path("/one"), Path("/two")])

    def test_sync_does_not_replace_unmanaged_skill_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target_root = Path(directory) / "skills"
            destination = target_root / "code-simplifier"
            destination.mkdir(parents=True)
            marker = destination / "keep"
            marker.write_text("user-owned")

            with mock.patch.dict(
                os.environ,
                {"AGENT_SKILLS_TARGETS": str(target_root)},
                clear=False,
            ):
                updater.sync_harness_links()

            self.assertEqual(marker.read_text(), "user-owned")


if __name__ == "__main__":
    unittest.main()
