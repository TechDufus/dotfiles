#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
DETECT_1PASSWORD = REPO_ROOT / "pre_tasks" / "detect_1password.yml"


class Detect1PasswordTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = DETECT_1PASSWORD.read_text(encoding="utf-8")

    def test_auth_detection_is_bounded_and_nonfatal(self) -> None:
        self.assertIn("Detect 1Password authentication state", self.tasks)
        self.assertIn("ansible_playbook_python", self.tasks)
        self.assertIn("subprocess.run", self.tasks)
        self.assertIn("timeout=5", self.tasks)
        self.assertIn("subprocess.TimeoutExpired", self.tasks)
        self.assertIn("sys.exit(124)", self.tasks)
        self.assertIn("failed_when: false", self.tasks)
        self.assertNotIn("async:", self.tasks)
        self.assertNotIn("poll:", self.tasks)

    def test_auth_fact_depends_only_on_successful_probe(self) -> None:
        self.assertIn("op_authenticated: \"{{ op_whoami.rc | default(1) == 0 }}\"", self.tasks)
        self.assertIn("when: op_installed", self.tasks)


if __name__ == "__main__":
    unittest.main()
