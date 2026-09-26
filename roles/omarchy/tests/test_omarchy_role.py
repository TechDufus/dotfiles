#!/usr/bin/env python3
from pathlib import Path
import ast
import unittest

import jinja2
import yaml


REPO_ROOT = Path(__file__).resolve().parents[3]


class OmarchyRoleSelectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.group_vars = yaml.safe_load(
            (REPO_ROOT / "group_vars" / "all.yml").read_text(encoding="utf-8")
        )
        main = yaml.safe_load((REPO_ROOT / "main.yml").read_text(encoding="utf-8"))
        cls.run_roles = jinja2.Environment().from_string(
            main[0]["tasks"][0]["ansible.builtin.set_fact"]["run_roles"]
        )

    def _run_roles(self, session: str, tags: list[str]) -> list[str]:
        rendered = self.run_roles.render(
            ansible_facts={"distribution": "Archlinux"},
            default_roles=self.group_vars["default_roles"],
            exclude_roles_by_distribution=self.group_vars["exclude_roles_by_distribution"],
            exclude_roles_by_session=self.group_vars["exclude_roles_by_session"],
            ansible_run_tags=tags,
            dotfiles_session=session,
        )
        return ast.literal_eval(rendered)

    def test_omarchy_session_full_run_drops_conflicting_roles(self) -> None:
        roles = self._run_roles("omarchy", ["all"])
        for role in ("plasma", "tldr", "neofetch"):
            self.assertNotIn(role, roles)
        for role in ("omarchy", "git", "fonts", "zsh", "neovim", "system"):
            self.assertIn(role, roles)

    def test_omarchy_session_drops_explicitly_tagged_plasma(self) -> None:
        self.assertEqual(self._run_roles("omarchy", ["plasma", "git"]), ["git"])

    def test_default_session_full_run_keeps_plasma_without_omarchy(self) -> None:
        roles = self._run_roles("default", ["all"])
        self.assertIn("plasma", roles)
        self.assertNotIn("omarchy", roles)

    def test_default_session_drops_explicitly_tagged_omarchy(self) -> None:
        self.assertEqual(self._run_roles("default", ["omarchy"]), [])


if __name__ == "__main__":
    unittest.main()
