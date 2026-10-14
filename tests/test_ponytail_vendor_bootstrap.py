import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "gridline" / "hooks" / "update_ponytail_vendor.py"
SPEC = importlib.util.spec_from_file_location("update_ponytail_vendor", SCRIPT)
vendor_update = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(vendor_update)


class PonytailVendorBootstrapTests(unittest.TestCase):
    def test_ensure_clones_once_and_prepares_gridline_adaptations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "gridline").mkdir()
            (root / "gridline" / "Package.swift").touch()
            hooks = root / "gridline" / "hooks"
            hooks.mkdir()
            git_calls = []

            def fake_git(arguments, cwd=None):
                git_calls.append(arguments)
                if arguments[0] == "clone":
                    checkout = Path(arguments[-1])
                    (checkout / ".git").mkdir(parents=True)
                    (checkout / "package.json").write_text('{"version":"5.2.1"}', encoding="utf-8")
                    (checkout / "skills" / "ponytail").mkdir(parents=True)
                    (checkout / "skills" / "ponytail" / "SKILL.md").write_text(
                        "---\nname: ponytail\n---\n\nPonytail instructions.\n", encoding="utf-8"
                    )
                    (checkout / "hooks").mkdir()
                    (checkout / "hooks" / "ponytail-map.js").write_text(
                        "const SKIP_DIR = /^(node_modules|\\.git|dist)$/;\n", encoding="utf-8"
                    )
                    (checkout / "LICENSE").write_text("MIT", encoding="utf-8")
                    (checkout / "assets").mkdir()
                    (checkout / "assets" / "logo-dark.png").write_bytes(b"logo")
                    return ""
                if arguments == ["rev-parse", "HEAD"]:
                    return "abc123"
                raise AssertionError(f"Unexpected git command: {arguments}")

            with patch.object(vendor_update, "git", side_effect=fake_git):
                first = vendor_update.ensure(root)
                second = vendor_update.ensure(root)

            vendor = root / "hook_vendor" / "ponytail"
            metadata = json.loads((vendor / "VENDOR_VERSION").read_text(encoding="utf-8"))
            map_source = (vendor / "hooks" / "ponytail-map.js").read_text(encoding="utf-8")
            template = (hooks / "ponytail.md.template").read_text(encoding="utf-8")

            self.assertTrue(first["ok"])
            self.assertTrue(second["ok"])
            self.assertEqual(metadata["commit"], "abc123")
            self.assertIn(r"|\.codex|", map_source)
            self.assertIn("Gridline adaptation", map_source)
            self.assertIn("Ponytail instructions.", template)
            self.assertEqual(sum(command[0] == "clone" for command in git_calls), 1)
            self.assertFalse(any(command[0] == "pull" for command in git_calls))


if __name__ == "__main__":
    unittest.main()
