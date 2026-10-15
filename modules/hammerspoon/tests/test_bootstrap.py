#!/usr/bin/env python3
"""Exercise the real installer with local ZIP releases and an isolated home."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "bootstrap.sh"


class SpoonBootstrap(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="spoon-fixtures-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.home = self.root / "home"
        self.spoons = self.home / ".hammerspoon/Spoons"
        self.spoons.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME",
                     "XDG_RUNTIME_DIR", "MISE_CONFIG_DIR", "MISE_DATA_DIR", "MISE_STATE_DIR",
                     "MISE_CACHE_DIR", "MISE_INSTALLS_DIR", "TMPDIR"):
            directory = self.root / name.lower()
            directory.mkdir()
            self.env[name] = str(directory)
        self.env["MISE_CONFIG_FILE"] = str(self.root / "mise.toml")
        self.env["FIXTURES"] = str(self.root)
        self.env["PATH"] = str(self.bin) + os.pathsep + os.environ["PATH"]
        self.command("curl", '''#!/bin/bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    https:*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */GridLayout.spoon.zip) cp "$FIXTURES/grid.zip" "$output" ;;
  */WorkspaceManager.spoon.zip) cp "$FIXTURES/wm.zip" "$output" ;;
  *) exit 99 ;;
esac
''')
        self.command("mktemp", '''#!/bin/bash
if [ "$#" -eq 1 ] && [ "$1" = -d ]; then
  exec /usr/bin/mktemp -d "$TMPDIR/spoons.XXXXXX"
fi
exec /usr/bin/mktemp "$@"
''')
        self.command("sudo", "#!/bin/bash\nexit 99\n")
        self.release("one")
        (self.spoons / "Unrelated.spoon").mkdir()
        (self.spoons / "Unrelated.spoon/keep").write_text("untouched")

    def command(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def release(self, version):
        with zipfile.ZipFile(self.root / "grid.zip", "w") as archive:
            for name in ("init.lua", "state.lua", "events.lua", "helpers.lua"):
                archive.writestr(name, "return {version = '" + version + "'}\n")
        with zipfile.ZipFile(self.root / "wm.zip", "w") as archive:
            for name in ("init.lua", "summon.lua", "workspace_manager.lua"):
                archive.writestr("WorkspaceManager.spoon/" + name,
                                 "-- " + version + "\nreturn hs.application.get(app.id) or hs.application.find(app.id)\n")

    def run_installer(self):
        result = subprocess.run(["bash", str(SCRIPT)], cwd=self.root, env=self.env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.spoons / "Unrelated.spoon/keep").read_text(), "untouched")
        return result.stdout

    def snapshot(self):
        return {str(path.relative_to(self.spoons)): (path.stat().st_ino, path.stat().st_mtime_ns,
                                                    path.read_bytes() if path.is_file() else None)
                for path in self.spoons.rglob("*")}

    def test_install_update_and_unchanged_repeat(self):
        self.run_installer()
        self.assertIn("one", (self.spoons / "GridLayout.spoon/init.lua").read_text())
        self.assertNotIn("application.find", (self.spoons / "WorkspaceManager.spoon/summon.lua").read_text())
        before = self.snapshot()
        self.run_installer()
        self.assertEqual(before, self.snapshot(), "unchanged releases must not trigger watcher writes")
        self.release("two")
        self.run_installer()
        self.assertIn("two", (self.spoons / "GridLayout.spoon/init.lua").read_text())
        self.assertIn("two", (self.spoons / "WorkspaceManager.spoon/init.lua").read_text())

    def test_corrupt_or_incomplete_release_preserves_both_installs(self):
        self.run_installer()
        before = self.snapshot()
        for archive in ("grid.zip", "wm.zip"):
            with self.subTest(archive=archive):
                self.release("two")
                (self.root / archive).write_bytes(b"not a ZIP")
                self.assertNotIn("updated", self.run_installer())
                self.assertEqual(before, self.snapshot())
        self.release("two")
        with zipfile.ZipFile(self.root / "wm.zip", "w") as archive:
            archive.writestr("WorkspaceManager.spoon/init.lua", "return {}")
        self.assertNotIn("updated", self.run_installer())
        self.assertEqual(before, self.snapshot())
        (self.root / "wm.zip").unlink()
        self.assertNotIn("updated", self.run_installer())
        self.assertEqual(before, self.snapshot())

    def test_replacement_failure_rolls_back_both_installs(self):
        self.run_installer()
        before = self.snapshot()
        self.release("two")
        real_mv = shutil.which("mv")
        for name in ("GridLayout.spoon", "WorkspaceManager.spoon"):
            with self.subTest(replacement=name):
                self.command("mv", '''#!/bin/bash
case "$1" in
  */new/''' + name + ''') exit 1 ;;
esac
exec "''' + real_mv + '''" "$@"
''')
                self.assertNotIn("updated", self.run_installer())
                self.assertEqual(before, self.snapshot())

    def test_term_immediately_after_backup_restores_originals(self):
        self.run_installer()
        before = self.snapshot()
        self.release("two")
        real_mv = shutil.which("mv")
        for name in ("GridLayout.spoon", "WorkspaceManager.spoon"):
            with self.subTest(backup=name):
                self.command("mv", '''#!/bin/bash
"''' + real_mv + '''" "$@" || exit "$?"
case "$2" in
  */old/''' + name + ''') kill -TERM "$PPID" ;;
esac
''')
                self.assertNotIn("updated", self.run_installer())
                self.assertEqual(before, self.snapshot())

    def test_failed_restore_retains_original_backup(self):
        self.run_installer()
        original = (self.spoons / "GridLayout.spoon/init.lua").read_bytes()
        self.release("two")
        real_mv = shutil.which("mv")
        self.command("mv", '''#!/bin/bash
case "$1" in
  */new/GridLayout.spoon|*/old/GridLayout.spoon) exit 1 ;;
esac
exec "''' + real_mv + '''" "$@"
''')
        output = self.run_installer()
        self.assertNotIn("updated", output)
        retained = list(self.spoons.glob(".bootstrap.*/old/GridLayout.spoon/init.lua"))
        self.assertEqual(len(retained), 1)
        self.assertEqual(retained[0].read_bytes(), original)
        self.assertIn(str(retained[0].parents[2]), output)


if __name__ == "__main__":
    unittest.main()
