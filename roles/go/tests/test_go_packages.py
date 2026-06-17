#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
PACKAGES = REPO_ROOT / "roles" / "go" / "tasks" / "packages.yml"
ARCH = REPO_ROOT / "roles" / "go" / "tasks" / "Archlinux.yml"


class GoRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.packages = PACKAGES.read_text(encoding="utf-8")
        cls.arch = ARCH.read_text(encoding="utf-8")

    def _task_block(self, start: str, end: str) -> str:
        return self.packages.split(start, 1)[1].split(end, 1)[0]

    def test_go_package_installs_use_creates_without_changed_override(self) -> None:
        install_block = self._task_block(
            "- name: Go-Lang | Install GoLang Packages",
            "- name: Go-Lang | Go packages skipped",
        )
        self.assertIn('cmd: "go install {{ item.package }}"', install_block)
        self.assertIn("creates: \"{{ ansible_facts['env']['HOME'] }}/go/bin/{{ item.cmd }}\"", install_block)
        self.assertNotIn("changed_when:", install_block)
        self.assertNotIn("register: go_install", install_block)

    def test_go_package_installs_skip_when_go_is_unavailable(self) -> None:
        self.assertIn("Go-Lang | Detect Go binary", self.packages)
        self.assertIn("check_mode: false", self.packages)
        self.assertIn("failed_when: false", self.packages)
        self.assertIn("go_binary.rc == 0", self.packages)
        self.assertIn("Go package installation skipped because go is not installed.", self.packages)

    def test_archlinux_installs_go_with_pacman_guard(self) -> None:
        self.assertIn("community.general.pacman", self.arch)
        self.assertIn("- go", self.arch)
        self.assertIn("can_install_packages | default(false)", self.arch)


if __name__ == "__main__":
    unittest.main()
