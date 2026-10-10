#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ARCH_TASKS = REPO_ROOT / "roles" / "zsh" / "tasks" / "Archlinux.yml"
ARCH_OS_FUNCTIONS = REPO_ROOT / "roles" / "zsh" / "files" / "os" / "Archlinux" / "os_functions.zsh"


class ArchDefaultShellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = ARCH_TASKS.read_text(encoding="utf-8")

    def test_arch_role_installs_and_selects_system_zsh(self) -> None:
        for required in [
            "community.general.pacman",
            "- zsh",
            "path: /usr/bin/zsh",
            "ansible.builtin.user:",
            "shell: /usr/bin/zsh",
            "become: true",
            "can_install_packages | default(false)",
        ]:
            self.assertIn(required, self.tasks)

    def test_arch_role_targets_dotfiles_user(self) -> None:
        self.assertIn("name: \"{{ host_user | default(ansible_facts['user_id']) }}\"", self.tasks)

    def test_arch_role_explains_manual_chsh_when_sudo_unavailable(self) -> None:
        self.assertIn("Default shell change skipped because sudo is unavailable.", self.tasks)
        self.assertIn("chsh -s /usr/bin/zsh", self.tasks)

    @unittest.skipUnless(shutil.which("zsh"), "zsh not installed")
    def test_update_alias_follows_platform_precedence(self) -> None:
        cases = [
            (["omarchy", "paru", "yay"], "omarchy update -y"),
            (["paru", "yay"], "paru -Syu --noconfirm"),
            (["yay"], "yay -Syu --noconfirm"),
            ([], "sudo pacman -Syu --noconfirm"),
        ]
        for commands, expected in cases:
            with self.subTest(commands=commands), tempfile.TemporaryDirectory() as stub_dir:
                for name in commands:
                    stub = Path(stub_dir) / name
                    stub.write_text("#!/bin/sh\n", encoding="utf-8")
                    stub.chmod(0o755)
                result = subprocess.run(
                    ["zsh", "-f", "-c", 'PATH="$1"; source "$2" && print -r -- "$aliases[update]"', "zsh", stub_dir, str(ARCH_OS_FUNCTIONS)],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.assertEqual(result.stdout.strip(), expected)


if __name__ == "__main__":
    unittest.main()
