#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS = REPO_ROOT / "roles" / "nvm" / "tasks" / "main.yml"


class NvmRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS.read_text(encoding="utf-8")

    def _block(self, start: str, end: str) -> str:
        return self.tasks.split(start, 1)[1].split(end, 1)[0]

    def test_install_precreates_nvm_dir_for_exported_env(self) -> None:
        self.assertIn('NVM | Ensure nvm directory exists', self.tasks)
        self.assertIn('path: "{{ ansible_facts[\'env\'][\'HOME\'] }}/.nvm"', self.tasks)
        self.assertIn('export NVM_DIR="{{ ansible_facts[\'env\'][\'HOME\'] }}/.nvm"', self.tasks)

    def test_install_update_is_not_blocked_by_creates(self) -> None:
        install_block = self._block(
            '- name: "NVM | Install or update nvm"',
            '- name: "NVM | Resolve installed Node.js version"',
        )
        self.assertIn('curl -fsSL', install_block)
        self.assertNotIn('creates:', install_block)

    def test_node_install_runs_after_fresh_nvm_install(self) -> None:
        resolve_block = self._block(
            '- name: "NVM | Resolve installed Node.js version"',
            '- name: "NVM | Check if Node.js version is already installed"',
        )
        self.assertIn('nvm_install_result is changed', resolve_block)
        self.assertIn('current_nvm_version.stdout != "not-installed"', resolve_block)
        self.assertNotIn('nvm_install_result is not changed', resolve_block)
        self.assertIn('nvm version "{{ nvm_node_version }}"', resolve_block)
        self.assertNotIn('ls-remote', resolve_block)

    def test_node_install_reports_unchanged_when_lts_exists(self) -> None:
        node_install_block = self._block(
            '- name: "NVM | Install Node.js version"',
            '- name: "NVM | Check current default Node.js version"',
        )
        self.assertIn("'is already installed' not in node_install_result.stdout", node_install_block)
        self.assertNotIn('creates:', node_install_block)

    def test_default_alias_check_reads_alias_file_exactly(self) -> None:
        default_block = self._block(
            '- name: "NVM | Check current default Node.js version"',
            '- name: "NVM | Set default Node.js version"',
        )
        self.assertIn('alias/default', default_block)
        self.assertIn('printf', default_block)
        self.assertNotIn('grep -oE', default_block)
        self.assertNotIn('sed ', default_block)


if __name__ == "__main__":
    unittest.main()
