#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ARCH_TASKS = REPO_ROOT / "roles" / "system" / "tasks" / "Archlinux.yml"
GROUP_VARS = REPO_ROOT / "group_vars" / "all.yml"


class ArchKeyboardConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = ARCH_TASKS.read_text(encoding="utf-8")
        cls.group_vars = GROUP_VARS.read_text(encoding="utf-8")

    def test_dvorak_defaults_are_declared(self) -> None:
        for required in [
            "keyboard:",
            "model: pc105",
            "layout: us",
            "variant: dvorak",
            "- caps:none",
        ]:
            self.assertIn(required, self.group_vars)

    def test_arch_system_role_manages_console_and_x11_keymaps(self) -> None:
        for required in [
            "localectl status",
            "set-keymap",
            "set-x11-keymap",
            "arch_console_keymap",
            "arch_x11_options",
            "can_install_packages | default(false)",
        ]:
            self.assertIn(required, self.tasks)

    def test_localectl_probe_runs_in_check_mode(self) -> None:
        self.assertIn("check_mode: false", self.tasks)
        self.assertIn("Keyboard skipped (localectl unavailable)", self.tasks)


if __name__ == "__main__":
    unittest.main()
