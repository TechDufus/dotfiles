#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = REPO_ROOT / "roles" / "clangd" / "tasks"


class ClangdPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = {
            distribution: (TASKS_DIR / f"{distribution}.yml").read_text(encoding="utf-8")
            for distribution in ("Archlinux", "Ubuntu", "Fedora", "MacOSX")
        }
        cls.dispatcher = (TASKS_DIR / "main.yml").read_text(encoding="utf-8")

    def test_distribution_tasks_install_the_native_package_mapping(self) -> None:
        expected_packages = {
            "Archlinux": "clang",
            "Ubuntu": "clangd",
            "Fedora": "clang-tools-extra",
            "MacOSX": "llvm",
        }
        package_modules = {
            "Archlinux": "community.general.pacman",
            "Ubuntu": "ansible.builtin.apt",
            "Fedora": "ansible.builtin.dnf",
            "MacOSX": "community.general.homebrew",
        }

        for distribution, package in expected_packages.items():
            with self.subTest(distribution=distribution):
                self.assertIn(package_modules[distribution], self.tasks[distribution])
                self.assertRegex(
                    self.tasks[distribution],
                    rf"(?m)^(?:\s+-\s+|\s+name:\s+){re.escape(package)}\s*$",
                )
                self.assertIn("state: present", self.tasks[distribution])
                self.assertIn(
                    "when: can_install_packages | default(false)",
                    self.tasks[distribution],
                )

    def test_distribution_dispatcher_selects_detected_distribution_file(self) -> None:
        self.assertIn("ansible_facts['distribution']", self.dispatcher)
        self.assertIn(
            'path: "{{ role_path }}/tasks/{{ ansible_facts[\'distribution\'] }}.yml"',
            self.dispatcher,
        )
        self.assertIn(
            'ansible.builtin.include_tasks: "{{ ansible_facts[\'distribution\'] }}.yml"',
            self.dispatcher,
        )
        self.assertIn("when: distribution_config.stat.exists", self.dispatcher)

    def test_macos_resolves_keg_only_llvm_and_links_clangd(self) -> None:
        macos = self.tasks["MacOSX"]
        self.assertIn("brew --prefix llvm", macos)
        self.assertIn("changed_when: false", macos)
        self.assertIn("{{ ansible_facts['env']['HOME'] }}/.local/bin", macos)
        self.assertIn("state: directory", macos)
        self.assertRegex(
            macos,
            r"src:\s*[\"']?\{\{\s*clangd_llvm_prefix\.stdout\s*\|\s*trim\s*\}\}/bin/clangd",
        )
        self.assertIn("{{ ansible_facts['env']['HOME'] }}/.local/bin/clangd", macos)
        self.assertIn("state: link", macos)
        self.assertIn("force: false", macos)
        self.assertNotIn("force: true", macos)
        self.assertIn("Refuse to overwrite conflicting clangd symlink", macos)
        self.assertIn("clangd_user_link.stat.lnk_source", macos)


if __name__ == "__main__":
    unittest.main()
