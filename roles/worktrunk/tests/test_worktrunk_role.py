#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_ROOT = REPO_ROOT / "roles" / "worktrunk"
TASKS = ROLE_ROOT / "tasks" / "main.yml"
DEFAULTS = ROLE_ROOT / "defaults" / "main.yml"
CONFIG = ROLE_ROOT / "files" / "config.toml"

WORKTREE_PATH = (
    '{{ repo_path }}/../.worktrees/{{ repo }}/{{ branch | sanitize }}'
)


def load_task_blocks(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    starts = [match.start() for match in re.finditer(r"(?m)^- name:", text)]
    return [
        text[start:end].rstrip()
        for start, end in zip(starts, starts[1:] + [len(text)])
    ]


class WorktrunkRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.main_tasks = load_task_blocks(TASKS)
        cls.main_text = TASKS.read_text(encoding="utf-8")
        cls.defaults = DEFAULTS.read_text(encoding="utf-8")
        cls.config = CONFIG.read_text(encoding="utf-8")

    def _task_with_action(self, tasks: list[str], action: str) -> str:
        matches = [task for task in tasks if action in task]
        self.assertEqual(len(matches), 1, f"expected one {action} task")
        return matches[0]

    def test_worktree_path_is_sibling_namespaced_and_not_a_jinja_template(self) -> None:
        self.assertIn(f'worktree-path = "{WORKTREE_PATH}"', self.config)
        self.assertNotIn(".j2", self.main_text)
        self.assertIn("ansible.builtin.copy:", self.main_text)
        self.assertNotIn("ansible.builtin.template:", self.main_text)

    def test_copy_deploys_tracked_config_after_distribution_install(self) -> None:
        dispatch = self._task_with_action(
            self.main_tasks, "ansible.builtin.include_tasks"
        )
        copy = self._task_with_action(self.main_tasks, "ansible.builtin.copy")
        self.assertLess(self.main_tasks.index(dispatch), self.main_tasks.index(copy))
        self.assertIn('    src: "config.toml"', copy)
        self.assertIn('    dest: "{{ worktrunk_config_dest }}"', copy)
        self.assertIn(
            'worktrunk_config_dest: "{{ ansible_facts[\'user_dir\'] }}/.config/worktrunk/config.toml"',
            self.defaults,
        )


if __name__ == "__main__":
    unittest.main()
