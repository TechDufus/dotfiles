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

    def test_node_version_resolution_prefers_remote_metadata(self) -> None:
        resolve_block = self._block(
            '- name: "NVM | Resolve installed Node.js version"',
            '- name: "NVM | Check if Node.js version is already installed"',
        )
        remote_lookup = 'remote_version="$(nvm version-remote "{{ nvm_node_version }}"'
        local_lookup = 'local_version="$(nvm version "{{ nvm_node_version }}"'
        self.assertIn(remote_lookup, resolve_block)
        self.assertIn(local_lookup, resolve_block)
        self.assertIn('[ "$remote_version" != "N/A" ]', resolve_block)
        self.assertIn('else\n      local_version=', resolve_block)
        self.assertLess(
            resolve_block.index(remote_lookup),
            resolve_block.index(local_lookup),
        )
        self.assertIn('printf \'%s\\n\' "$remote_version"', resolve_block)

    def test_node_install_stat_uses_normalized_version(self) -> None:
        stat_block = self._block(
            '- name: "NVM | Check if Node.js version is already installed"',
            '- name: "NVM | Install Node.js version"',
        )
        self.assertIn("{{ node_version_normalized.stdout }}", stat_block)

    def test_node_install_reports_unchanged_when_target_exists(self) -> None:
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
