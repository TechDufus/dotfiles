#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_ROOT = REPO_ROOT / "roles" / "claude"
TASKS_PATH = ROLE_ROOT / "tasks" / "main.yml"
DEFAULTS_PATH = ROLE_ROOT / "defaults" / "main.yml"
SKILLS_DIR = ROLE_ROOT / "files" / "skills"
EXPECTED_SKILLS = {
    "skill-creator",
}


def load_task_blocks(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    starts = [match.start() for match in re.finditer(r"(?m)^- name:", text)]
    return [
        text[start:end].rstrip()
        for start, end in zip(starts, starts[1:] + [len(text)])
    ]


class ClaudeRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS_PATH.read_text(encoding="utf-8")
        cls.task_blocks = load_task_blocks(TASKS_PATH)
        cls.defaults = DEFAULTS_PATH.read_text(encoding="utf-8")
        cls.readme = (ROLE_ROOT / "README.md").read_text(encoding="utf-8")

    def _task_named(self, title: str) -> str:
        matches = [task for task in self.task_blocks if title in task.splitlines()[0]]
        self.assertEqual(len(matches), 1, f"expected one task named {title}")
        return matches[0]

    def test_skills_are_copied_per_directory_and_not_whole_tree_symlinks(self) -> None:
        skill_names = {path.name for path in SKILLS_DIR.iterdir() if path.is_dir()}
        self.assertEqual(skill_names, EXPECTED_SKILLS)
        for skill in skill_names:
            self.assertTrue((SKILLS_DIR / skill / "SKILL.md").is_file())

        self.assertIn("claude_skills_source", self.defaults)
        self.assertIn("claude_skills_dest", self.defaults)
        self.assertIn('claude_skills_dest: "{{ claude_config_root }}/skills"', self.defaults)

        copy = self._task_named("Copy repo-managed Claude skills")
        self.assertIn("ansible.builtin.copy:", copy)
        self.assertIn("mode: preserve", copy)
        self.assertNotIn("state: link", copy)

        replace_tree = self._task_named("Replace leftover Claude skills directory symlink")
        self.assertIn("state: absent", replace_tree)
        self.assertIn("claude_skills_dest_stat.stat.islnk", replace_tree)

        remove_skill_links = self._task_named(
            "Remove leftover Claude skill destination symlinks"
        )
        self.assertIn("item.stat.islnk", remove_skill_links)
        self.assertNotIn("not (item.stat.islnk", remove_skill_links)

        self.assertNotIn("Create symlink to Claude skills", self.tasks)
        self.assertNotIn(
            "Remove existing skills directory if it's not a symlink",
            self.tasks,
        )
        self.assertNotIn("Remove stale", self.tasks)
        self.assertNotIn(
            'dest: "{{ ansible_facts[\'env\'][\'HOME\'] }}/.claude/skills"',
            self.tasks,
        )

        self.assertIn("never symlink the whole directory", self.readme.lower())
        self.assertIn("does not delete destination skills", self.readme.lower())
        self.assertIn("`skill-creator`", self.readme)


if __name__ == "__main__":
    unittest.main()
