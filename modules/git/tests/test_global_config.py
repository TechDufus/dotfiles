#!/usr/bin/env python3
"""Exercise the shipped migration and actual Git; all identities are fixture-only."""

import contextlib
import io
import os
from pathlib import Path
import runpy
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


MODULE = Path(__file__).resolve().parents[1]
GIT = shutil.which("git")
# Historical native-mise output, not imported from the migration implementation.
OLD_COMMON = """# >>> mise:dotfiles >>> managed by mise — do not edit between markers
[include]
\tpath = ~/.config/git/dotfiles.gitconfig
\tpath = ~/.config/git/identity.gitconfig
# <<< mise:dotfiles <<<
"""
OLD_MAC = """# >>> mise:dotfiles-macos >>> managed by mise — do not edit between markers
[include]
\tpath = ~/.config/git/dotfiles-macos.gitconfig
# <<< mise:dotfiles-macos <<<
"""


class GitGlobalConsumption(unittest.TestCase):
    def setUp(self):
        if GIT is None:
            self.fail("real Git is required by the Git module test gate")
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-git-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir(mode=0o700)
        self.config = self.home / ".gitconfig"
        self.git_dir = self.home / ".config/git"
        self.git_dir.mkdir(parents=True)
        self.xdg_config = self.git_dir / "config"
        self.identity = self.git_dir / "identity.gitconfig"
        for name in ("dotfiles.gitconfig", "dotfiles-macos.gitconfig", "commit_template"):
            shutil.copyfile(MODULE / name, self.git_dir / name)
        self.write_identity("first@example.invalid", "first.pub")
        # Never inherit the caller's Git injection, home, XDG files or repository.
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
        self.repo = self.home / "consumer"
        self.git("init", "--quiet", str(self.repo), cwd=self.home)

    def git(self, *args, cwd=None):
        result = subprocess.run([GIT, *args], env=self.env, cwd=cwd or self.repo,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 0, "fixture Git command failed: " + result.stderr)
        return result.stdout.rstrip("\n")

    def apply(self, warning=False):
        result = subprocess.run([sys.executable, str(MODULE / "bootstrap.py")],
                                env=self.env, cwd=self.home, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 0, "migration must fail soft")
        self.assertEqual(result.stdout, "", "migration must not expose config values")
        if warning:
            self.assertIn("git:", result.stderr)
            self.assertIn("skipped", result.stderr)
        else:
            self.assertEqual(result.stderr, "")
        return result

    def write_identity(self, email, key):
        self.identity.write_text(
            "[user]\n\temail = " + email + "\n\tsigningkey = ~/.ssh/" + key + "\n"
            "[gpg]\n\tformat = ssh\n[commit]\n\tgpgsign = true\n"
            "[tag]\n\tgpgsign = true\n[gpg \"ssh\"]\n"
            "\tallowedSignersFile = ~/.config/git/allowed_signers\n"
        )

    def assert_managed(self, email="first@example.invalid", key="first.pub"):
        expected = {
            "user.name": "TechDufus", "init.defaultBranch": "main", "pull.ff": "only",
            "user.email": email, "user.signingkey": "~/.ssh/" + key,
            "gpg.format": "ssh", "commit.gpgsign": "true", "tag.gpgsign": "true",
            "gpg.ssh.allowedSignersFile": "~/.config/git/allowed_signers",
        }
        for name, value in expected.items():
            with self.subTest(setting=name):
                self.assertEqual(self.git("config", "--get", name), value)
        # A legacy XDG compatibility include would load the identity twice, even
        # though a simple --get still returned the right winning value.
        origins = self.git("config", "--show-origin", "--get-all", "user.email").splitlines()
        self.assertEqual(sum("identity.gitconfig" in line for line in origins), 1)

    def test_fresh_home_rotation_and_repository_override(self):
        self.apply()
        self.assert_managed()
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        before = self.config.read_bytes()
        inode = self.config.stat().st_ino
        self.write_identity("rotated@example.invalid", "rotated.pub")
        self.apply()
        self.assert_managed("rotated@example.invalid", "rotated.pub")
        self.assertEqual(self.config.read_bytes(), before)
        self.assertEqual(self.config.stat().st_ino, inode, "unchanged application should not rewrite globals")
        self.git("config", "--local", "user.email", "repository@example.invalid")
        self.git("config", "--local", "commit.gpgsign", "false")
        self.assertEqual(self.git("config", "--get", "user.email"), "repository@example.invalid")
        self.assertEqual(self.git("config", "--type=bool", "--get", "commit.gpgsign"), "false")

    def test_legacy_globals_preserve_bytes_and_win_after_later_user_edits(self):
        unrelated_xdg = b"# keep XDG bytes\n[fixture]\n\txdg = retained\n"
        self.xdg_config.write_bytes(unrelated_xdg + OLD_COMMON.encode() + OLD_MAC.encode())
        historical = (
            b"# historical globals remain exactly here\n[fixture]\n\ttraditional = retained\n"
            b"[user]\n\tname = Previous Name\n\temail = previous@example.invalid\n"
            b"\tsigningkey = previous-key\n[gpg]\n\tformat = openpgp\n"
            b"[commit]\n\tgpgsign = false\n[tag]\n\tgpgsign = false\n"
            b"[gpg \"ssh\"]\n\tallowedSignersFile = previous-signers\n"
            b"[init]\n\tdefaultBranch = historical"
        )
        self.config.write_bytes(historical)
        self.config.chmod(0o640)
        self.apply()
        self.assert_managed()
        self.assertTrue(self.config.read_bytes().startswith(historical + b"\n"))
        self.assertEqual(self.xdg_config.read_bytes(), unrelated_xdg)
        self.assertEqual(self.git("config", "--get", "fixture.xdg"), "retained")
        self.assertEqual(self.git("config", "--get", "fixture.traditional"), "retained")
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)
        once = self.config.read_bytes()
        self.apply()
        self.assertEqual(self.config.read_bytes(), once)
        # Git/appended user config can move the managed block away from EOF.
        # Reapply must restore managed precedence, not merely replace it in place.
        tail = b"[user]\n\temail = later@example.invalid\n"
        with self.config.open("ab") as stream:
            stream.write(tail)
        self.apply()
        self.assert_managed()
        self.assertIn(tail, self.config.read_bytes())
        self.assertTrue(self.xdg_config.exists(), "migration never deletes a global file")

    def test_alternate_xdg_root_is_cleaned_without_wholesale_deletion(self):
        alternate = self.home / "xdg/git/config"
        alternate.parent.mkdir(parents=True)
        alternate.write_text("# preserve alternate root\n" + OLD_COMMON)
        self.env["XDG_CONFIG_HOME"] = str(self.home / "xdg")
        self.xdg_config.write_text(OLD_COMMON)
        self.apply()
        self.assert_managed()
        self.assertEqual(alternate.read_text(), "# preserve alternate root\n")
        self.assertEqual(self.xdg_config.read_bytes(), b"")

    def test_customized_or_damaged_legacy_block_aborts_before_any_write(self):
        self.config.write_text("[fixture]\n\ttraditional = retained\n")
        for content in (OLD_COMMON.replace("identity.gitconfig", "custom.gitconfig"),
                        OLD_COMMON + OLD_COMMON,
                        OLD_COMMON.split("# <<<")[0]):
            with self.subTest(content=content):
                self.xdg_config.write_text(content)
                original = self.config.read_bytes()
                self.apply(warning=True)
                self.assertEqual(self.config.read_bytes(), original)
                self.assertEqual(self.xdg_config.read_text(), content)

    def test_symlink_file_or_parent_never_mutates_link_destination(self):
        other = Path(self.temp.name) / "unmanaged"
        other.write_text("[fixture]\n\tunmanaged = retained\n")
        self.config.symlink_to(other)
        self.apply(warning=True)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(other.read_text(), "[fixture]\n\tunmanaged = retained\n")
        self.config.unlink()
        moved = self.home / "linked-config"
        (self.home / ".config").rename(moved)
        (self.home / ".config").symlink_to(moved, target_is_directory=True)
        (moved / "git/config").write_text(OLD_COMMON)
        self.apply(warning=True)
        self.assertFalse(self.config.exists())
        self.assertEqual((moved / "git/config").read_text(), OLD_COMMON)

    def test_existing_lock_or_readonly_global_preserves_both_globals(self):
        self.xdg_config.write_text(OLD_COMMON)
        self.config.write_text("# keep me\n")
        lock = self.home / ".gitconfig.lock"
        lock.write_text("another writer owns this lock\n")
        self.apply(warning=True)
        self.assertEqual(lock.read_text(), "another writer owns this lock\n")
        self.assertEqual(self.xdg_config.read_text(), OLD_COMMON)
        lock.unlink()
        self.config.chmod(0o400)
        self.apply(warning=True)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o400)
        self.assertEqual(self.config.read_text(), "# keep me\n")
        self.assertEqual(self.xdg_config.read_text(), OLD_COMMON)

    def test_interrupted_cleanup_keeps_signing_policy_and_rerun_finishes(self):
        unrelated = b"# retain traditional globals\n[fixture]\n\ttraditional = retained\n"
        xdg = "# retain XDG globals\n" + OLD_COMMON
        self.config.write_bytes(unrelated)
        self.xdg_config.write_text(xdg)
        self.assertEqual(self.git("config", "--type=bool", "--get", "commit.gpgsign"), "true")
        namespace = runpy.run_path(str(MODULE / "bootstrap.py"))
        real_replace = os.replace
        replacements = 0

        def interrupt_second_replace(source, destination):
            nonlocal replacements
            replacements += 1
            if replacements == 2:
                raise OSError("fixture interruption during obsolete block cleanup")
            return real_replace(source, destination)

        warning = io.StringIO()
        with mock.patch.dict(os.environ, self.env, clear=True), \
                mock.patch("os.replace", side_effect=interrupt_second_replace), \
                contextlib.redirect_stderr(warning):
            self.assertEqual(namespace["main"](), 0)
        self.assertEqual(replacements, 2, "fixture must reach the second replacement")
        self.assertIn("skipped remaining changes", warning.getvalue())
        self.assertEqual(self.git("config", "--type=bool", "--get", "commit.gpgsign"), "true")
        self.assertEqual(self.git("config", "--type=bool", "--get", "tag.gpgsign"), "true")
        self.assertTrue(self.config.read_bytes().startswith(unrelated))
        self.assertEqual(self.xdg_config.read_text(), xdg)
        self.assertFalse(self.config.with_name(".gitconfig.lock").exists())
        self.assertFalse(self.xdg_config.with_name("config.lock").exists())
        self.apply()
        self.assert_managed()
        self.assertTrue(self.config.read_bytes().startswith(unrelated))
        self.assertEqual(self.xdg_config.read_text(), "# retain XDG globals\n")

    def test_unmanaged_duplicate_include_aborts_without_deleting_user_content(self):
        original = "[include]\n\tpath = ~/.config/git/identity.gitconfig\n"
        self.config.write_text(original)
        self.xdg_config.write_text(OLD_COMMON)
        self.apply(warning=True)
        self.assertEqual(self.config.read_text(), original)
        self.assertEqual(self.xdg_config.read_text(), OLD_COMMON)

    def test_invalid_global_config_is_not_overwritten(self):
        original = "[unterminated\n"
        self.config.write_text(original)
        self.xdg_config.write_text(OLD_COMMON)
        self.apply(warning=True)
        self.assertEqual(self.config.read_text(), original)
        self.assertEqual(self.xdg_config.read_text(), OLD_COMMON)

    def test_redirected_global_path_is_not_touched(self):
        redirected = self.home / "intentional-global"
        redirected.write_text("[user]\n\temail = intentional@example.invalid\n")
        self.env["GIT_CONFIG_GLOBAL"] = str(redirected)
        self.apply(warning=True)
        self.assertFalse(self.config.exists())
        self.assertEqual(redirected.read_text(), "[user]\n\temail = intentional@example.invalid\n")


if __name__ == "__main__":
    unittest.main()
