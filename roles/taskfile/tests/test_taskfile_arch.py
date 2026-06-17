#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS = REPO_ROOT / "roles" / "taskfile" / "tasks" / "main.yml"
ARCH_TASKFILE = REPO_ROOT / "roles" / "taskfile" / "files" / "os" / "Taskfile_Archlinux.yml"


class TaskfileArchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS.read_text(encoding="utf-8")
        cls.arch = ARCH_TASKFILE.read_text(encoding="utf-8")

    def test_role_loads_archlinux_os_taskfile(self) -> None:
        self.assertIn("Taskfile_{{ ansible_facts['distribution'] }}.yml", self.tasks)
        self.assertTrue(ARCH_TASKFILE.exists())

    def test_directory_setup_does_not_force_check_mode(self) -> None:
        update_completions_block = self.tasks.split(
            "- name: TASKFILE | Load OS-Specific Taskfile",
            1,
        )[0]
        self.assertIn("TASKFILE | Ensure .task config dir exists", update_completions_block)
        self.assertIn("TASKFILE | Ensure .task/completions dir exists", update_completions_block)
        self.assertNotIn("check_mode: false", update_completions_block)

    def test_role_skips_managed_marker_when_check_mode_has_no_dest(self) -> None:
        self.assertIn("TASKFILE | Check copied user Taskfile", self.tasks)
        self.assertIn("taskfile_user_taskfile", self.tasks)
        self.assertIn("(not ansible_check_mode) or (taskfile_user_taskfile.stat.exists | default(false))", self.tasks)

    def test_arch_taskfile_uses_pacman_full_upgrades(self) -> None:
        self.assertIn("sudo pacman -Syu --disable-download-timeout", self.arch)
        self.assertNotIn("apt-get", self.arch)
        self.assertNotIn("flatpak update", self.arch)

    def test_arch_taskfile_exposes_cutover_checks(self) -> None:
        self.assertIn("desktop-health:", self.arch)
        self.assertIn("Validate Plasma/summon/Steam runtime state", self.arch)
        self.assertIn("plasma-summon-service --print-config", self.arch)
        self.assertIn("systemctl --user is-active plasma-summon.service", self.arch)
        self.assertIn("steam-health --runtime --strict", self.arch)
        self.assertIn("dotfiles --check -t system,plasma,steam", self.arch)


if __name__ == "__main__":
    unittest.main()
