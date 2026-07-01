#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
BUN_DEFAULTS = REPO_ROOT / "roles" / "bun" / "defaults" / "main.yml"
NVIM_LSP = REPO_ROOT / "roles" / "neovim" / "files" / "lua" / "plugins" / "lsp.lua"

BUN_PACKAGE_TO_LSP_SERVER = {
    "@ansible/ansible-language-server": "ansiblels",
    "@astrojs/language-server": "astro",
    "@tailwindcss/language-server": "tailwindcss",
    "bash-language-server": "bashls",
    "dockerfile-language-server-nodejs": "dockerls",
    "graphql-language-service-cli": "graphql",
    "pyright": "pyright",
    "svelte-language-server": "svelte",
    "typescript-language-server": "ts_ls",
    "yaml-language-server": "yamlls",
}

BUN_PACKAGES_WITHOUT_LSP_SERVER = {
    "typescript",
}


def _extract_bun_global_packages(defaults_text: str) -> list[str]:
    packages: list[str] = []
    in_packages = False

    for line in defaults_text.splitlines():
        if line == "bun_global_packages:":
            in_packages = True
            continue

        if not in_packages:
            continue

        if line.startswith("  - "):
            packages.append(line.split("- ", 1)[1].strip().strip('"').strip("'"))
            continue

        if line and not line.startswith(" ") and not line.startswith("#"):
            break

    return packages


def _extract_neovim_lsp_servers(lsp_text: str) -> set[str]:
    match = re.search(r"local\s+lsp_servers\s*=\s*{(?P<body>.*?)\n}", lsp_text, re.DOTALL)
    if match is None:
        raise AssertionError("Could not find local lsp_servers table")

    return set(re.findall(r'"([^"]+)"', match.group("body")))


class NeovimLspServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bun_packages = _extract_bun_global_packages(BUN_DEFAULTS.read_text(encoding="utf-8"))
        cls.nvim_lsp_servers = _extract_neovim_lsp_servers(NVIM_LSP.read_text(encoding="utf-8"))

    def test_bun_language_server_packages_have_explicit_mason_mapping(self) -> None:
        unmapped = sorted(
            package
            for package in self.bun_packages
            if package not in BUN_PACKAGE_TO_LSP_SERVER
            and package not in BUN_PACKAGES_WITHOUT_LSP_SERVER
        )
        self.assertEqual([], unmapped)

        stale_mappings = sorted(
            package
            for package in BUN_PACKAGE_TO_LSP_SERVER
            if package not in self.bun_packages
        )
        self.assertEqual([], stale_mappings)

    def test_neovim_mason_installs_bun_managed_language_servers(self) -> None:
        expected_servers = {
            BUN_PACKAGE_TO_LSP_SERVER[package]
            for package in self.bun_packages
            if package in BUN_PACKAGE_TO_LSP_SERVER
        }
        missing_servers = sorted(expected_servers - self.nvim_lsp_servers)

        self.assertEqual([], missing_servers)


if __name__ == "__main__":
    unittest.main()
