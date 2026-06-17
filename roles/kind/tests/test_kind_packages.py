#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
UBUNTU = REPO_ROOT / "roles" / "kind" / "tasks" / "Ubuntu.yml"


class KindRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ubuntu = UBUNTU.read_text(encoding="utf-8")

    def _install_block(self) -> str:
        return self.ubuntu.split("- name: kind | Install kind with Go", 1)[1]

    def test_kind_install_uses_creates_without_changed_override(self) -> None:
        install_block = self._install_block()
        self.assertIn('cmd: "go install {{ item.package }}"', install_block)
        self.assertIn("creates: \"{{ ansible_facts['env']['HOME'] }}/go/bin/{{ item.cmd }}\"", install_block)
        self.assertNotIn("changed_when:", install_block)
        self.assertNotIn("register: go_install", install_block)


if __name__ == "__main__":
    unittest.main()
