#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ZSHRC = REPO_ROOT / "roles" / "zsh" / "files" / ".zshrc"
ZSHENV = REPO_ROOT / "roles" / "zsh" / "files" / ".zshenv"
TASKS = REPO_ROOT / "roles" / "zsh" / "tasks" / "main.yml"


class ZshrcStructureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.zshrc = ZSHRC.read_text(encoding="utf-8")
        cls.zshenv = ZSHENV.read_text(encoding="utf-8")
        cls.tasks = TASKS.read_text(encoding="utf-8")

    def test_plugin_load_order(self) -> None:
        self.assertLess(self.zshrc.index("compinit"), self.zshrc.index("Aloxaf/fzf-tab"))
        self.assertLess(self.zshrc.index("Aloxaf/fzf-tab"), self.zshrc.index("zsh-autosuggestions"))
        self.assertLess(
            self.zshrc.index("zsh-autosuggestions"),
            self.zshrc.index("zsh-syntax-highlighting"),
        )

    def test_cursor_agent_and_herdr_helpers_exist(self) -> None:
        self.assertIn("is_cursor_agent()", self.zshrc)
        self.assertIn("is_agent_shell()", self.zshrc)
        self.assertIn("is_herdr_session()", self.zshrc)
        self.assertIn("CURSOR_AGENT", self.zshrc)
        self.assertIn("CLAUDECODE", self.zshrc)
        self.assertIn("NO_NOMATCH", self.zshenv)
        self.assertIn("brew shellenv", self.zshenv)
        self.assertIn("paths_functions.zsh", self.zshenv)
        self.assertIn("paths_vars.zsh", self.zshenv)
        self.assertNotIn('eval "$(/opt/homebrew/bin/brew shellenv)"', self.zshrc)
        self.assertIn("paths_functions.zsh|paths_vars.zsh", self.zshrc)

    def test_nvm_hook_does_not_auto_install(self) -> None:
        nvm_config = (REPO_ROOT / "roles" / "zsh" / "files" / "zsh" / "nvm_config.zsh").read_text(
            encoding="utf-8"
        )
        self.assertIn('echo "nvm: node $(cat "${nvmrc_path}") is not installed. Run: nvm install"', nvm_config)
        self.assertNotIn("\n        nvm install\n", nvm_config)

    def test_fzf_is_initialized_once(self) -> None:
        self.assertIn('eval "$(fzf --zsh)"', self.zshrc)
        self.assertNotIn(".fzf.zsh", self.zshrc)
        self.assertEqual(self.zshrc.count("bindkey '^n'"), 1)

    def test_dropped_omz_snippets(self) -> None:
        self.assertNotIn("OMZP::globalias", self.zshrc)
        self.assertNotIn("OMZP::kubectl", self.zshrc)
        self.assertNotIn("OMZP::kubectx", self.zshrc)

    def test_ansible_deploys_zshenv_and_zinit(self) -> None:
        self.assertIn('src: ".zshenv"', self.tasks)
        self.assertIn("zdharma-continuum/zinit.git", self.tasks)
        self.assertIn("depth: 1", self.tasks)

    def test_secrets_are_not_autoloaded(self) -> None:
        self.assertNotIn("secret", self.zshenv)
        self.assertNotIn("with-secrets", self.zshenv)
        self.assertNotIn("__secret_ensure_loaded", self.zshrc)
        self.assertNotIn("secret --quiet", self.zshrc)
        self.assertIn("src: bin/with-secrets", self.tasks)
        secret_functions = (
            REPO_ROOT / "roles" / "zsh" / "files" / "zsh" / "vars.secret_functions.zsh"
        ).read_text(encoding="utf-8")
        self.assertIn("function with-secrets()", secret_functions)
        self.assertIn("function __secret_ensure_loaded()", secret_functions)
        self.assertIn("ORCA_SKIP_SECRETS", secret_functions)


if __name__ == "__main__":
    unittest.main()
