#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
DETECT_SUDO = REPO_ROOT / "pre_tasks" / "detect_sudo.yml"


class DetectSudoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = DETECT_SUDO.read_text(encoding="utf-8")

    def test_password_sudo_does_not_grant_privilege_without_credentials(self) -> None:
        self.assertIn("sudo_password_based_available: false", self.tasks)
        self.assertIn("Record password-based sudo availability", self.tasks)
        self.assertIn("sudo_password_based_available: true", self.tasks)

        password_sudo_block = self.tasks.split(
            "- name: Detect password-based sudo availability", 1
        )[1].split("- name: Determine package installation capability", 1)[0]
        self.assertIn("has_sudo: true", password_sudo_block)
        self.assertIn("privilege_escalation_available: true", password_sudo_block)
        self.assertIn("sudo_credentials_cached: false", password_sudo_block)
        self.assertIn("- sudo_binary_check.rc | default(1) == 0", password_sudo_block)
        self.assertIn(
            "- become_password_available | default(false) | bool",
            password_sudo_block,
        )

    def test_become_password_detected_before_password_sudo_fallback(self) -> None:
        self.assertLess(
            self.tasks.index("- name: Detect provided become password"),
            self.tasks.index("- name: Detect password-based sudo availability"),
        )
        self.assertIn("ansible_become_password", self.tasks)
        self.assertIn("ansible_become_pass", self.tasks)
        self.assertIn("ansible_sudo_pass", self.tasks)

    def test_cached_or_password_supplied_sudo_allows_package_installs(self) -> None:
        capability_block = self.tasks.split(
            "- name: Determine package installation capability", 1
        )[1].split("- name: Warn when sudo password is required", 1)[0]
        self.assertIn("has_sudo", capability_block)
        self.assertIn("not (sudo_requires_password | bool)", capability_block)
        self.assertIn(
            "sudo_credentials_cached | default(false) | bool",
            capability_block,
        )
        self.assertIn(
            "become_password_available | default(false) | bool",
            capability_block,
        )

    def test_password_sudo_without_credentials_warns_before_skip(self) -> None:
        warning_block = self.tasks.split(
            "- name: Warn when sudo password is required", 1
        )[1].split("- name: Display privilege escalation detection results", 1)[0]
        self.assertIn(
            "sudo_password_based_available | default(false) | bool",
            warning_block,
        )
        self.assertIn(
            "not (sudo_credentials_cached | default(false) | bool)",
            warning_block,
        )
        self.assertIn(
            "not (become_password_available | default(false) | bool)",
            warning_block,
        )
        self.assertNotIn("- has_sudo", warning_block)
        self.assertNotIn("sudo_method == 'sudo'", warning_block)
        self.assertIn("--ask-become-pass", warning_block)


if __name__ == "__main__":
    unittest.main()
