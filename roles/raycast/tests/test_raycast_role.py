#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS = REPO_ROOT / "roles" / "raycast" / "tasks" / "MacOSX.yml"


class RaycastRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS.read_text(encoding="utf-8")

    def _task_block(self, name: str) -> str:
        marker = f'- name: "{name}"'
        self.assertIn(marker, self.tasks)
        block = marker + self.tasks.split(marker, 1)[1]
        return block.split('\n- name: "', 1)[0]

    def test_role_does_not_use_homebrew_cask_path(self) -> None:
        for forbidden in (
            "homebrew_cask",
            "brew uninstall",
            "name: raycast",
            "--cask raycast",
        ):
            self.assertNotIn(forbidden, self.tasks)

    def test_beta_dmg_url_is_resolved_from_download_page(self) -> None:
        self.assertIn("https://www.raycast.com/new", self.tasks)
        self.assertIn("regex_findall", self.tasks)
        self.assertIn("Raycast_Beta_", self.tasks)
        self.assertIn("_arm64\\\\.dmg", self.tasks)
        self.assertNotIn("Raycast_Beta_0.66.1.0", self.tasks)

    def test_beta_app_idempotency_checks_app_bundle_directory(self) -> None:
        stat_block = self._task_block("Raycast | MacOSX | Check if Raycast Beta is installed")
        state_block = self._task_block("Raycast | MacOSX | Determine Raycast Beta installed state")
        post_install_state_block = self._task_block("Raycast | MacOSX | Determine Raycast Beta post-install state")
        check_mode_block = self._task_block("Raycast | MacOSX | Note Raycast Beta install in check mode")
        install_block = self._task_block("Raycast | MacOSX | Install Raycast Beta")

        self.assertIn("path: /Applications/Raycast Beta.app", stat_block)
        self.assertIn("raycast_beta_app.stat.exists | default(false)", state_block)
        self.assertIn("and raycast_beta_app.stat.isdir | default(false)", state_block)
        self.assertIn("or (ansible_check_mode and not raycast_beta_installed)", post_install_state_block)
        self.assertIn("- not raycast_beta_installed", check_mode_block)
        self.assertIn("- not raycast_beta_installed", install_block)

    def test_stable_cleanup_runs_only_after_beta_is_present(self) -> None:
        cleanup_check_block = self._task_block("Raycast | MacOSX | Check manually installed stable Raycast app")
        cleanup_block = self._task_block("Raycast | MacOSX | Remove manually installed stable Raycast app")

        self.assertIn("raycast_beta_installed_after_install | default(false)", cleanup_check_block)
        self.assertIn("path: /Applications/Raycast.app", cleanup_block)
        self.assertIn("state: absent", cleanup_block)
        self.assertIn("become: true", cleanup_block)
        self.assertIn("raycast_beta_installed_after_install | default(false)", cleanup_block)
        self.assertIn("raycast_stable_app.stat.exists", cleanup_block)

    def test_existing_beta_file_fails_fast_before_install(self) -> None:
        fail_block = self._task_block("Raycast | MacOSX | Fail when Raycast Beta path is not an app bundle")

        self.assertIn("ansible.builtin.fail", fail_block)
        self.assertIn("exists but is not a directory", fail_block)
        self.assertIn("raycast_beta_app.stat.exists", fail_block)
        self.assertIn("not raycast_beta_app.stat.isdir", fail_block)


if __name__ == "__main__":
    unittest.main()
