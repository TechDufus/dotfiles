#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_ROOT = REPO_ROOT / "roles" / "orca"
CANONICAL = ROLE_ROOT / "files" / "skills" / "orca"
CURSOR_SKILLS = REPO_ROOT / "roles" / "cursor" / "files" / "skills"
OMP_SKILLS = REPO_ROOT / "roles" / "omp" / "files" / "skills"
CODEX_SKILLS = REPO_ROOT / "roles" / "codex" / "files" / "skills"
CLAUDE_SKILLS = REPO_ROOT / "roles" / "claude" / "files" / "skills"


class OrcaPromptSkillTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.defaults = (ROLE_ROOT / "defaults" / "main.yml").read_text(encoding="utf-8")
        cls.tasks = (ROLE_ROOT / "tasks" / "main.yml").read_text(encoding="utf-8")
        cls.readme = (ROLE_ROOT / "README.md").read_text(encoding="utf-8")

    def test_other_roles_do_not_vendor_the_skill(self) -> None:
        self.assertFalse((CURSOR_SKILLS / "orca").exists())
        self.assertFalse((OMP_SKILLS / "orca").exists())
        self.assertFalse((CODEX_SKILLS / "orca").exists())
        self.assertFalse((CLAUDE_SKILLS / "orca").exists())
        cursor_tasks = (REPO_ROOT / "roles" / "cursor" / "tasks" / "main.yml").read_text(
            encoding="utf-8"
        )
        omp_tasks = (REPO_ROOT / "roles" / "omp" / "tasks" / "main.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("spawn-prompt skill", cursor_tasks)
        self.assertNotIn("spawn-prompt skill", omp_tasks)

    def test_orca_role_owns_dest_symlinks(self) -> None:
        self.assertIn("orca_prompt_skill_source", self.defaults)
        self.assertIn(".cursor/skills/", self.defaults)
        self.assertIn(".omp/agent/skills/", self.defaults)
        self.assertIn(".codex/skills/", self.defaults)
        self.assertIn(".claude/skills/", self.defaults)
        self.assertIn("Check spawn-prompt skill homes", self.tasks)
        self.assertIn("Skip unmanaged spawn-prompt skill destinations", self.tasks)
        self.assertIn("Symlink spawn-prompt skill into agent homes", self.tasks)
        self.assertIn("does not add the skill to Cursor, OMP, Codex, or Claude role file trees", self.readme)
        self.assertIn("orca_prompt_skill_dests", self.readme)
        self.assertIn("ask for the exact word they type", self.readme)
        self.assertIn("Do not invent examples", self.readme)

    def test_skill_is_slash_only_prompt_tips(self) -> None:
        self.assertTrue((CANONICAL / "SKILL.md").is_file())
        text = (CANONICAL / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("disable-model-invocation: true", text)
        self.assertIn("Use only when the user invokes /orca", text)
        self.assertIn("orchestration skill", text)
        self.assertIn("/orchestrate", text)
        self.assertIn("workflowz", text)
        self.assertIn("Standalone lowercase", text)
        self.assertIn("Not the Orca CLI", text)
        self.assertIn("ask before adding a row", text)
        self.assertNotIn("worker-start", text)
        self.assertNotIn("--spec", text)
        self.assertNotIn("/herd", text)
        self.assertNotIn("Codex", text)


if __name__ == "__main__":
    unittest.main()
