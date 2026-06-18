#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ARCH_TASKS = REPO_ROOT / "roles" / "zsh" / "tasks" / "Archlinux.yml"
ARCH_OS_FUNCTIONS = REPO_ROOT / "roles" / "zsh" / "files" / "os" / "Archlinux" / "os_functions.zsh"


class ArchDefaultShellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = ARCH_TASKS.read_text(encoding="utf-8")

        cls.os_functions = ARCH_OS_FUNCTIONS.read_text(encoding="utf-8")

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

    def test_arch_os_functions_define_update_and_cleanup_helpers(self) -> None:
        for required in [
            "alias update='paru -Syu --noconfirm'",
            "alias update='yay -Syu --noconfirm'",
            "alias update='sudo pacman -Syu --noconfirm'",
            "alias pacorphans='pacman -Qtdq'",
            "clean-system()",
        ]:
            self.assertIn(required, self.os_functions)


if __name__ == "__main__":
    unittest.main()
