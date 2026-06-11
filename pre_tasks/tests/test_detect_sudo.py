#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
DETECT_SUDO = REPO_ROOT / "pre_tasks" / "detect_sudo.yml"


class DetectSudoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = DETECT_SUDO.read_text(encoding="utf-8")

    def test_password_sudo_is_recorded_without_cached_credentials(self) -> None:
        self.assertIn("Detect password-based sudo availability", self.tasks)
        self.assertIn("Check sudo binary for password-based escalation", self.tasks)
        self.assertIn("sudo_credentials_cached: false", self.tasks)
        self.assertIn("sudo_method: 'sudo'", self.tasks)
        self.assertIn("sudo_requires_password: true", self.tasks)

    def test_cached_or_passwordless_sudo_allows_package_installs(self) -> None:
        self.assertIn("sudo_credentials_cached: true", self.tasks)
        self.assertIn("become_password_available", self.tasks)
        self.assertIn("ansible_become_password", self.tasks)

    def test_password_sudo_without_credentials_warns_before_skip(self) -> None:
        self.assertIn("Warn when sudo password is required", self.tasks)
        self.assertIn("sudo -v", self.tasks)
        self.assertIn("--ask-become-pass", self.tasks)
        self.assertIn("ansible_become_pass", self.tasks)
        self.assertIn("ansible_sudo_pass", self.tasks)
        self.assertIn("sudo_credentials_cached | default(false)", self.tasks)


if __name__ == "__main__":
    unittest.main()
