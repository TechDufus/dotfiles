#!/usr/bin/env python3
"""Execution-level safety tests for the OMP Ansible role."""

from __future__ import annotations

import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_DIR = REPO_ROOT / "roles/omp"
PLAYBOOK = """---
- name: Apply OMP role to a disposable local fixture
  hosts: localhost
  gather_facts: true
  tasks:
    - name: Apply the OMP role
      ansible.builtin.include_role:
        name: omp
"""


def find_omp_binary() -> Path | None:
    configured = os.environ.get("OMP_TEST_REAL_BIN")
    return Path(configured) if configured else None


def base_role_variables(root: Path, real_bin: Path | None = None) -> dict[str, Any]:
    home = root / "home"
    agent_dir = home / ".omp/agent"
    return {
        "omp_manage_install": False,
        "omp_bun_candidate_bins": [],
        "omp_real_bin": str(real_bin or (root / "bin/omp-not-installed")),
        "omp_config_root": str(home / ".omp"),
        "omp_agent_dir": str(agent_dir),
        "omp_config_path": str(agent_dir / "config.yml"),
        "omp_mcp_config_path": str(agent_dir / "mcp.json"),
        "omp_lsp_config_path": str(agent_dir / "lsp.json"),
        "omp_overlays_dest": str(agent_dir / "overlays"),
        "omp_launchers_dest": str(home / ".local/bin"),
        "omp_watchdog_dest": str(agent_dir / "WATCHDOG.md"),
        "omp_rules_dest": str(agent_dir / "RULES.md"),
        "omp_agents_dest": str(agent_dir / "agents"),
        "omp_skills_dest": str(agent_dir / "skills"),
        "omp_extensions_dest": str(agent_dir / "extensions"),
        "omp_config_validation_tmpdir": str(root / "config-validation-tmp"),
        "omp_herdr_integration_enabled": False,
        "omp_herdr_skill_enabled": False,
        "omp_worktrunk_skill_enabled": False,
    }


class OmpRoleSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ansible_playbook = shutil.which("ansible-playbook")
        if not ansible_playbook:
            raise unittest.SkipTest("ansible-playbook is required for OMP role safety tests")
        cls.ansible_playbook = Path(ansible_playbook).resolve()
        cls.official_omp = find_omp_binary()

    def create_fixture(self, root: Path, overrides: dict[str, Any] | None = None) -> dict[str, Any]:
        root.mkdir(parents=True, exist_ok=True)
        for relative in (
            "home",
            "ansible-tmp/local",
            "ansible-tmp/remote",
            "config-validation-tmp",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        variables = base_role_variables(root)
        if overrides:
            variables.update(overrides)
        (root / "role-playbook.yml").write_text(PLAYBOOK, encoding="utf-8")
        (root / "role-vars.json").write_text(
            json.dumps(variables, sort_keys=True), encoding="utf-8"
        )
        ansible_config = root / "ansible.cfg"
        ansible_config.write_text(
            "\n".join(
                (
                    "[defaults]",
                    f"roles_path = {ROLE_DIR.parent}",
                    "host_key_checking = False",
                    "retry_files_enabled = False",
                    "interpreter_python = auto_silent",
                    f"local_tmp = {root / 'ansible-tmp/local'}",
                    f"remote_tmp = {root / 'ansible-tmp/remote'}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        return variables

    def run_role(
        self,
        root: Path,
        variables: dict[str, Any],
        *,
        check_mode: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        (root / "role-vars.json").write_text(
            json.dumps(variables, sort_keys=True), encoding="utf-8"
        )
        executable_dirs = {
            self.ansible_playbook.parent,
            Path(sys.executable).parent,
            Path(str(variables["omp_real_bin"])).parent,
            Path("/opt/homebrew/bin"),
            Path("/usr/local/bin"),
            Path("/usr/bin"),
            Path("/bin"),
            Path("/usr/sbin"),
            Path("/sbin"),
        }
        utf8_locale = "en_US.UTF-8" if sys.platform == "darwin" else "C.UTF-8"
        environment = {
            "HOME": str(root / "home"),
            "PATH": os.pathsep.join(str(path) for path in sorted(executable_dirs)),
            "TMPDIR": str(root / "ansible-tmp"),
            "TMP": str(root / "ansible-tmp"),
            "TEMP": str(root / "ansible-tmp"),
            "LANG": utf8_locale,
            "LC_ALL": utf8_locale,
            "ANSIBLE_CONFIG": str(root / "ansible.cfg"),
            "ANSIBLE_HOME": str(root / ".ansible"),
            "ANSIBLE_LOCAL_TEMP": str(root / "ansible-tmp/local"),
            "ANSIBLE_REMOTE_TEMP": str(root / "ansible-tmp/remote"),
            "ANSIBLE_ROLES_PATH": str(ROLE_DIR.parent),
            "ANSIBLE_NOCOLOR": "1",
        }
        command = [
            str(self.ansible_playbook),
            "--inventory",
            "localhost,",
            "--connection",
            "local",
            "--limit",
            "localhost",
            "--forks",
            "1",
            "--extra-vars",
            f"@{root / 'role-vars.json'}",
        ]
        if check_mode:
            command.append("--check")
        command.append(str(root / "role-playbook.yml"))
        return subprocess.run(
            command,
            cwd=root,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
            timeout=120,
        )

    @staticmethod
    def changed_count(result: subprocess.CompletedProcess[str]) -> int:
        match = re.search(r"\bchanged=(\d+)\b", result.stdout)
        if not match:
            raise AssertionError("Ansible play recap did not report a changed count")
        return int(match.group(1))

    def assert_role_succeeded(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(
            result.returncode,
            0,
            f"Ansible role failed without exposing config data:\n{result.stdout}\n{result.stderr}",
        )

    def test_fresh_apply_and_reapply_are_idempotent_in_scratch_home(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omp-role-safety-") as temporary:
            root = Path(temporary)
            overrides = {"omp_real_bin": str(self.official_omp)} if self.official_omp else None
            variables = self.create_fixture(root, overrides)

            first = self.run_role(root, variables)
            self.assert_role_succeeded(first)
            self.assertGreater(self.changed_count(first), 0)
            validation_tmp = Path(variables["omp_config_validation_tmpdir"])
            self.assertEqual(list(validation_tmp.iterdir()), [])

            config_dest = Path(variables["omp_config_path"])
            self.assertTrue(config_dest.is_symlink())
            self.assertEqual(os.readlink(config_dest), str(ROLE_DIR / "files/config.yml"))
            agent_dest = Path(variables["omp_agents_dest"]) / "security-auditor.md"
            self.assertEqual(
                os.readlink(agent_dest),
                str(ROLE_DIR / "files/agents/security-auditor.md"),
            )
            skill_dest = Path(variables["omp_skills_dest"]) / "commit"
            self.assertEqual(os.readlink(skill_dest), str(ROLE_DIR / "files/skills/commit"))
            self.assertFalse((Path(variables["omp_agent_dir"]) / "AGENTS.md").is_symlink())

            second = self.run_role(root, variables)
            self.assert_role_succeeded(second)
            self.assertEqual(self.changed_count(second), 0)
            self.assertEqual(list(validation_tmp.iterdir()), [])

    def test_agent_skill_and_foreign_link_collisions_preserve_user_data(self) -> None:
        cases = ("agent", "skill", "link", "extension")
        for collision in cases:
            with self.subTest(collision=collision), tempfile.TemporaryDirectory(
                prefix="omp-role-collision-"
            ) as temporary:
                root = Path(temporary)
                variables = self.create_fixture(root)
                if collision == "agent":
                    target = Path(variables["omp_agents_dest"]) / "security-auditor.md"
                    target.parent.mkdir(parents=True, exist_ok=True)
                    marker = b"user-owned agent data\n"
                    target.write_bytes(marker)
                elif collision == "skill":
                    target = Path(variables["omp_skills_dest"]) / "commit"
                    (target / "references").mkdir(parents=True)
                    marker = b"user-owned skill data\n"
                    (target / "references/user.txt").write_bytes(marker)
                else:
                    if collision == "link":
                        target = Path(variables["omp_overlays_dest"]) / "herd.yml"
                        marker = b"user-owned overlay data\n"
                    else:
                        target = Path(variables["omp_extensions_dest"]) / "herd.ts"
                        marker = b"user-owned extension data\n"
                    target.parent.mkdir(parents=True, exist_ok=True)
                    link_target = root / "user-managed-file"
                    link_target.write_bytes(marker)
                    target.symlink_to(link_target)

                result = self.run_role(root, variables)
                self.assertNotEqual(result.returncode, 0, "collision unexpectedly succeeded")
                self.assertIn(str(target), result.stdout + result.stderr)
                if collision in ("link", "extension"):
                    self.assertTrue(target.is_symlink())
                    self.assertEqual(os.readlink(target), str(link_target))
                    self.assertEqual(link_target.read_bytes(), marker)
                elif collision == "skill":
                    self.assertTrue(target.is_dir())
                    self.assertEqual((target / "references/user.txt").read_bytes(), marker)
                else:
                    self.assertEqual(target.read_bytes(), marker)


    def test_agents_copy_refuses_symlink_and_nonregular_collisions(self) -> None:
        for collision in ("symlink", "directory"):
            with self.subTest(collision=collision), tempfile.TemporaryDirectory(
                prefix="omp-role-agents-collision-"
            ) as temporary:
                root = Path(temporary)
                variables = self.create_fixture(root)
                guidance = Path(variables["omp_agent_dir"]) / "AGENTS.md"
                guidance.parent.mkdir(parents=True, exist_ok=True)
                marker = b"synthetic pre-existing guidance\n"
                if collision == "symlink":
                    link_target = root / "user-guidance.md"
                    link_target.write_bytes(marker)
                    guidance.symlink_to(link_target)
                else:
                    guidance.mkdir()
                    (guidance / "user.txt").write_bytes(marker)

                result = self.run_role(root, variables)
                self.assertNotEqual(result.returncode, 0, "guidance collision unexpectedly succeeded")
                self.assertIn(str(guidance), result.stdout + result.stderr)
                if collision == "symlink":
                    self.assertTrue(guidance.is_symlink())
                    self.assertEqual(os.readlink(guidance), str(link_target))
                    self.assertEqual(link_target.read_bytes(), marker)
                else:
                    self.assertTrue(guidance.is_dir())
                    self.assertEqual((guidance / "user.txt").read_bytes(), marker)

    def test_check_mode_refuses_foreign_managed_link_without_mutation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omp-role-check-mode-") as temporary:
            root = Path(temporary)
            variables = self.create_fixture(root)
            agent_dir = Path(variables["omp_agent_dir"])
            overlays = Path(variables["omp_overlays_dest"])
            overlays.mkdir(parents=True, exist_ok=True)
            link_target = root / "user-overlay.yml"
            original = b"synthetic check-mode overlay\n"
            link_target.write_bytes(original)
            destination = overlays / "herd.yml"
            destination.symlink_to(link_target)

            result = self.run_role(root, variables, check_mode=True)
            self.assertNotEqual(result.returncode, 0, "foreign managed link unexpectedly passed")
            self.assertIn(str(destination), result.stdout + result.stderr)
            self.assertTrue(agent_dir.is_dir())
            self.assertTrue(destination.is_symlink())
            self.assertEqual(os.readlink(destination), str(link_target))
            self.assertEqual(link_target.read_bytes(), original)

    def test_changed_regular_agents_guidance_is_backed_up_before_copy(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omp-role-guidance-") as temporary:
            root = Path(temporary)
            variables = self.create_fixture(root)
            guidance = Path(variables["omp_agent_dir"]) / "AGENTS.md"
            guidance.parent.mkdir(parents=True, exist_ok=True)
            original = b"synthetic user guidance\n"
            guidance.write_bytes(original)
            guidance.chmod(0o600)

            result = self.run_role(root, variables)
            self.assert_role_succeeded(result)

            backups = list(
                (Path(variables["omp_agent_dir"]) / ".dotfiles-backups/guidance").glob(
                    "AGENTS.md.*"
                )
            )
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), original)
            self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o600)
            expected = (ROLE_DIR / "files/AGENTS.md").read_bytes()
            self.assertEqual(guidance.read_bytes(), expected)
            self.assertEqual(stat.S_IMODE(guidance.stat().st_mode), 0o644)

    def test_extension_backup_and_mcp_merge_preserve_synthetic_user_data(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omp-role-preservation-") as temporary:
            root = Path(temporary)
            variables = self.create_fixture(root)
            extensions = Path(variables["omp_extensions_dest"])
            extensions.mkdir(parents=True, exist_ok=True)
            extension = extensions / "herd.ts"
            old_extension = b"synthetic pre-existing extension\n"
            extension.write_bytes(old_extension)
            extension.chmod(0o640)
            unrelated_extension = extensions / "user-extension.ts"
            unrelated_extension.write_bytes(b"unmanaged extension\n")

            mcp_path = Path(variables["omp_mcp_config_path"])
            mcp_path.parent.mkdir(parents=True, exist_ok=True)
            old_mcp = {
                "localMetadata": {"retained": True},
                "mcpServers": {
                    "personal": {"type": "stdio", "command": "synthetic-tool"},
                    "playwright": {"type": "http", "url": "synthetic-old-value"},
                },
            }
            mcp_path.write_text(json.dumps(old_mcp), encoding="utf-8")
            mcp_path.chmod(0o600)

            result = self.run_role(root, variables)
            self.assert_role_succeeded(result)

            backups = list((Path(variables["omp_agent_dir"]) / ".dotfiles-backups/extensions").glob("herd.ts.*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), old_extension)
            self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o640)
            self.assertTrue(extension.is_symlink())
            self.assertEqual(os.readlink(extension), str(ROLE_DIR / "files/extensions/herd.ts"))
            self.assertEqual(unrelated_extension.read_bytes(), b"unmanaged extension\n")

            merged = json.loads(mcp_path.read_text(encoding="utf-8"))
            self.assertEqual(merged["localMetadata"], {"retained": True})
            self.assertEqual(
                merged["mcpServers"]["personal"],
                {"type": "stdio", "command": "synthetic-tool"},
            )
            self.assertEqual(merged["mcpServers"]["playwright"]["type"], "stdio")
            self.assertEqual(merged["mcpServers"]["playwright"]["command"], "bunx")
            self.assertEqual(stat.S_IMODE(mcp_path.stat().st_mode), 0o600)

    def test_malformed_source_config_is_unchanged_and_validation_scratch_is_removed(self) -> None:
        if (
            not self.official_omp
            or not self.official_omp.is_file()
            or not os.access(self.official_omp, os.X_OK)
        ):
            self.skipTest("set OMP_TEST_REAL_BIN to an installed official omp binary")

        with tempfile.TemporaryDirectory(prefix="omp-role-invalid-config-") as temporary:
            root = Path(temporary)
            malformed = root / "managed-source/config.yml"
            malformed.parent.mkdir(parents=True)
            original = b"synthetic-marker: [unterminated\n"
            malformed.write_bytes(original)
            variables = self.create_fixture(
                root,
                {
                    "omp_config_source": str(malformed),
                    "omp_real_bin": str(self.official_omp),
                },
            )
            validation_tmp = Path(variables["omp_config_validation_tmpdir"])

            result = self.run_role(root, variables)
            self.assertNotEqual(result.returncode, 0, "malformed config unexpectedly validated")
            self.assertEqual(malformed.read_bytes(), original)
            self.assertTrue(Path(variables["omp_config_path"]).is_symlink())
            self.assertEqual(os.readlink(variables["omp_config_path"]), str(malformed))
            self.assertEqual(list(validation_tmp.iterdir()), [])
            self.assertNotIn("synthetic-marker", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
