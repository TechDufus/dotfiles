#!/usr/bin/env python3
from pathlib import Path
import re
import tomllib
import unittest



REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_ROOT = REPO_ROOT / "roles" / "herdr"
TASKS_ROOT = ROLE_ROOT / "tasks"
GROUP_VARS_ROOT = REPO_ROOT / "group_vars"


def load_task_blocks(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    starts = [match.start() for match in re.finditer(r"(?m)^- name:", text)]
    return [
        text[start:end].rstrip()
        for start, end in zip(starts, starts[1:] + [len(text)])
    ]


def parse_top_level_list(text: str, key: str) -> list[str]:
    lines = text.splitlines()
    try:
        start = lines.index(f"{key}:") + 1
    except ValueError as error:
        raise AssertionError(f"missing top-level list {key}") from error

    values = []
    for line in lines[start:]:
        if line and not line[0].isspace():
            break
        match = re.match(r"^\s+-\s+([^#\s]+)", line)
        if match:
            values.append(match.group(1))
    return values


class HerdrRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with (ROLE_ROOT / "files" / "config.toml").open("rb") as stream:
            cls.config = tomllib.load(stream)

        cls.main_tasks = load_task_blocks(TASKS_ROOT / "main.yml")
        cls.release_tasks = load_task_blocks(
            TASKS_ROOT / "install_github_release.yml"
        )
        cls.current_group_vars_text = (GROUP_VARS_ROOT / "all.yml").read_text(
            encoding="utf-8"
        )
        cls.example_group_vars_text = (GROUP_VARS_ROOT / "all.yml.example").read_text(
            encoding="utf-8"
        )

    def _task_with_action(self, tasks: list[str], action: str) -> str:
        action_line = re.compile(rf"(?m)^  {re.escape(action)}:")
        matches = [task for task in tasks if action_line.search(task)]
        self.assertEqual(len(matches), 1, f"expected one task using {action}")
        return matches[0]

    def test_managed_config_has_expected_onboarding_ui_and_navigation(self) -> None:
        self.assertIs(self.config["onboarding"], False)
        ui = self.config["ui"]
        self.assertIs(ui["show_agent_labels_on_pane_borders"], True)
        self.assertEqual(ui["agent_panel_sort"], "priority")
        self.assertEqual(ui["sidebar_width"], 38)
        self.assertEqual(ui["sidebar_min_width"], 26)
        self.assertEqual(ui["sidebar_max_width"], 48)
        self.assertEqual(
            ui["sidebar"]["agents"],
            {
                "row_gap": 0,
                "rows": [
                    ["state_icon", "agent", "$model"],
                    ["terminal_title_stripped"],
                    ["workspace"],
                ],
            },
        )
        self.assertEqual(ui["toast"], {"delivery": "terminal"})
        keys = self.config["keys"]
        self.assertEqual(keys["focus_pane_left"], ["prefix+h", "ctrl+h"])
        self.assertEqual(keys["focus_pane_down"], ["prefix+j", "ctrl+j"])
        self.assertEqual(keys["focus_pane_up"], ["prefix+k", "ctrl+k"])
        self.assertEqual(keys["focus_pane_right"], ["prefix+l", "ctrl+l"])
        self.assertEqual(keys["previous_agent"], ["prefix+alt+p", "ctrl+alt+k"])
        self.assertEqual(keys["next_agent"], ["prefix+alt+n", "ctrl+alt+j"])
        self.assertEqual(keys["focus_agent"], "prefix+alt+1..9")

    def test_main_dispatches_distribution_before_deploying_managed_config(self) -> None:
        dispatch = self._task_with_action(
            self.main_tasks, "ansible.builtin.include_tasks"
        )
        copy = self._task_with_action(self.main_tasks, "ansible.builtin.copy")

        self.assertIn(
            "  ansible.builtin.include_tasks: "
            "\"{{ ansible_facts['distribution'] }}.yml\"",
            dispatch,
        )
        self.assertLess(self.main_tasks.index(dispatch), self.main_tasks.index(copy))
        self.assertIn("  ansible.builtin.copy:", copy)
        self.assertIn(
            "    dest: "
            "\"{{ ansible_facts['user_dir'] }}/.config/herdr/config.toml\"",
            copy,
        )
        self.assertIn('    src: "config.toml"', copy)
        self.assertIn('    mode: "0644"', copy)

    def test_macos_installs_stable_homebrew_formula(self) -> None:
        tasks = load_task_blocks(TASKS_ROOT / "MacOSX.yml")
        install = self._task_with_action(tasks, "community.general.homebrew")

        self.assertIn("  community.general.homebrew:", install)
        self.assertIn("    name: herdr", install)
        self.assertIn("    state: present", install)

    def test_supported_linux_distributions_use_shared_release_installer(self) -> None:
        for distribution in ("Archlinux", "Fedora", "Ubuntu", "Debian"):
            with self.subTest(distribution=distribution):
                tasks = load_task_blocks(TASKS_ROOT / f"{distribution}.yml")
                include = self._task_with_action(
                    tasks, "ansible.builtin.include_tasks"
                )
                self.assertIn(
                    "  ansible.builtin.include_tasks: install_github_release.yml",
                    include,
                )

    def test_shared_release_installer_selects_expected_upstream_binary(self) -> None:
        install = self._task_with_action(
            self.release_tasks, "ansible.builtin.include_role"
        )

        self.assertIn("  ansible.builtin.include_role:", install)
        self.assertIn("    name: github_release", install)
        self.assertIn(
            '    github_release_repo: "ogulcancelik/herdr"', install
        )
        self.assertIn('    github_release_binary_name: "herdr"', install)
        self.assertIn('    github_release_asset_type: "binary"', install)
        self.assertIn(
            "    github_release_asset_name_pattern: "
            "\"herdr-linux-{{ ansible_facts['architecture'] "
            "| replace('arm64', 'aarch64') }}\"",
            install,
        )
        self.assertIn(
            '    github_release_check_command: "herdr --version"', install
        )
        self.assertIn(
            "    github_release_version_pattern: '[0-9]+\\.[0-9]+\\.[0-9]+'",
            install,
        )

    def test_shared_release_installer_respects_package_install_privilege(self) -> None:
        path_task = self._task_with_action(
            self.release_tasks, "ansible.builtin.set_fact"
        )
        install = self._task_with_action(
            self.release_tasks, "ansible.builtin.include_role"
        )

        self.assertIn(
            "    herdr_install_path: "
            "\"{{ '/usr/local/bin' if can_install_packages | default(false) "
            "else ansible_facts['user_dir'] + '/.local/bin' }}\"",
            path_task,
        )
        self.assertIn(
            '    github_release_install_path: "{{ herdr_install_path }}"',
            install,
        )
        self.assertIn(
            "    github_release_become: "
            "\"{{ can_install_packages | default(false) }}\"",
            install,
        )

    def test_current_profile_enables_herdr_and_example_keeps_it_opt_in(self) -> None:
        self.assertIn(
            "herdr",
            parse_top_level_list(self.current_group_vars_text, "default_roles"),
        )
        self.assertRegex(
            self.example_group_vars_text,
            re.compile(
                r"^\s*#\s*-\s+herdr\s+#\s+Terminal workspace for parallel coding agents\s*$",
                re.MULTILINE,
            ),
        )


if __name__ == "__main__":
    unittest.main()
