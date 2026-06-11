#!/usr/bin/env python3
from __future__ import annotations

import importlib.machinery
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import subprocess
import unittest
from unittest.mock import patch
from tempfile import TemporaryDirectory
import contextlib
import io


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "roles" / "steam" / "files" / "bin" / "steam-health"
TASKS = REPO_ROOT / "roles" / "steam" / "tasks" / "Archlinux.yml"
MAIN_TASKS = REPO_ROOT / "roles" / "steam" / "tasks" / "main.yml"
FALLBACK_SESSION = REPO_ROOT / "roles" / "steam" / "files" / "bin" / "dotfiles-gamescope-steam-session"
FALLBACK_DESKTOP = REPO_ROOT / "roles" / "steam" / "files" / "gamescope" / "dotfiles-gamescope-steam.desktop"


loader = importlib.machinery.SourceFileLoader("steam_health", str(SCRIPT))
spec = importlib.util.spec_from_loader("steam_health", loader)
assert spec is not None
steam_health = importlib.util.module_from_spec(spec)
loader.exec_module(steam_health)


def completed(argv: list[str], returncode: int = 0, stdout: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(argv, returncode, stdout=stdout, stderr="")


class SteamHealthTests(unittest.TestCase):
    def test_arch_stack_requires_multilib_and_packages(self) -> None:
        queried_packages: list[str] = []

        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv == ["pacman-conf", "--repo-list"]:
                return completed(argv, stdout="core\nextra\nmultilib\n")
            if argv[:2] == ["pacman", "-Q"]:
                queried_packages.append(argv[2])
                return completed(argv, stdout=f"{argv[2]} 1-1\n")
            self.fail(f"unexpected command: {argv}")

        with patch.object(steam_health, "command", return_value="/usr/bin/tool"), patch.object(steam_health, "run", side_effect=fake_run):
            results = list(steam_health.check_arch_stack())

        self.assertEqual([result.level for result in results], ["pass", "pass"])
        self.assertIn("lib32-mangohud", queried_packages)
        self.assertIn("lib32-gamemode", queried_packages)

    def test_arch_stack_fails_without_multilib(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv == ["pacman-conf", "--repo-list"]:
                return completed(argv, stdout="core\nextra\n")
            if argv[:2] == ["pacman", "-Q"]:
                return completed(argv, stdout=f"{argv[2]} 1-1\n")
            self.fail(f"unexpected command: {argv}")

        with patch.object(steam_health, "command", return_value="/usr/bin/tool"), patch.object(steam_health, "run", side_effect=fake_run):
            results = list(steam_health.check_arch_stack())

        self.assertEqual(results[0].level, "fail")
        self.assertEqual(results[1].level, "pass")

    def test_vulkan_matches_any_nvidia_gpu_name(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:2] == ["vulkaninfo", "--summary"]:
                return completed(argv, stdout="GPU id = 0 (NVIDIA Example GPU)\n")
            if argv[:2] == ["nvidia-smi", "--query-gpu=name"]:
                return completed(argv, stdout="NVIDIA Example GPU\n")
            self.fail(f"unexpected command: {argv}")

        with (
            patch.object(steam_health, "command", return_value="/usr/bin/tool"),
            patch.object(steam_health, "nvidia_icd_files", return_value=[Path("/usr/share/vulkan/icd.d/nvidia_icd.json")]),
            patch.object(steam_health, "run", side_effect=fake_run),
        ):
            results = list(steam_health.check_vulkan())

        self.assertEqual([result.level for result in results], ["pass", "pass"])
        self.assertIn("NVIDIA Example GPU", results[1].detail)

    def test_vulkan_warns_when_summary_lacks_nvidia_gpu_name(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:2] == ["vulkaninfo", "--summary"]:
                return completed(argv, stdout="GPU id = 0 (llvmpipe)\n")
            if argv[:2] == ["nvidia-smi", "--query-gpu=name"]:
                return completed(argv, stdout="NVIDIA Example GPU\n")
            self.fail(f"unexpected command: {argv}")

        with (
            patch.object(steam_health, "command", return_value="/usr/bin/tool"),
            patch.object(steam_health, "nvidia_icd_files", return_value=[]),
            patch.object(steam_health, "run", side_effect=fake_run),
        ):
            results = list(steam_health.check_vulkan())

        self.assertEqual([result.level for result in results], ["warn", "warn"])

    def test_gamemode_warns_until_group_membership_is_active(self) -> None:
        with (
            patch.object(steam_health.getpass, "getuser", return_value="techdufus"),
            patch.object(steam_health.grp, "getgrnam", return_value=SimpleNamespace(gr_mem=["techdufus"])),
            patch.object(steam_health.os, "getgroups", return_value=[1000]),
            patch.object(steam_health.grp, "getgrgid", return_value=SimpleNamespace(gr_name="users")),
            patch.object(steam_health, "command", return_value=None),
        ):
            results = list(steam_health.check_gamemode(runtime=True))

        self.assertEqual(results[0].level, "warn")
        self.assertIn("log out/in", results[0].detail)

    def test_gamemode_passes_when_group_membership_is_active(self) -> None:
        with (
            patch.object(steam_health.getpass, "getuser", return_value="techdufus"),
            patch.object(steam_health.grp, "getgrnam", return_value=SimpleNamespace(gr_mem=["techdufus"])),
            patch.object(steam_health.os, "getgroups", return_value=[959]),
            patch.object(steam_health.grp, "getgrgid", return_value=SimpleNamespace(gr_name="gamemode")),
            patch.object(steam_health, "command", return_value=None),
        ):
            results = list(steam_health.check_gamemode(runtime=True))

        self.assertEqual(results[0].level, "pass")

    def test_gamescope_static_accepts_session_exec(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            sessions = root / "sessions"
            sessions.mkdir()
            (sessions / "gamescope-custom.desktop").write_text(
                "[Desktop Entry]\nName=Gamescope\nExec=env FOO=bar start-gamescope-session\n",
                encoding="utf-8",
            )
            gamescope = root / "gamescope"
            gamescope.write_text("", encoding="utf-8")

            def fake_command(name: str) -> str | None:
                if name in {"start-gamescope-session", "getcap"}:
                    return f"/usr/bin/{name}"
                return None

            def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
                if argv[:1] == ["getcap"]:
                    return completed(argv, stdout=f"{gamescope} cap_sys_nice=eip\n")
                self.fail(f"unexpected command: {argv}")

            with (
                patch.object(steam_health, "WAYLAND_SESSIONS_DIR", sessions),
                patch.object(steam_health, "GAMESCOPE_BINARY", gamescope),
                patch.object(steam_health, "command", side_effect=fake_command),
                patch.object(steam_health, "run", side_effect=fake_run),
            ):
                results = list(steam_health.check_gamescope_static())

        self.assertEqual([result.level for result in results], ["pass", "pass", "pass"])

    def test_fallback_gamescope_session_is_managed_when_cachyos_package_is_missing(self) -> None:
        tasks = TASKS.read_text(encoding="utf-8")
        script = FALLBACK_SESSION.read_text(encoding="utf-8")
        desktop = FALLBACK_DESKTOP.read_text(encoding="utf-8")

        for required in [
            "src: bin/dotfiles-gamescope-steam-session",
            "dest: /usr/local/bin/dotfiles-gamescope-steam-session",
            "src: gamescope/dotfiles-gamescope-steam.desktop",
            "dest: /usr/share/wayland-sessions/dotfiles-gamescope-steam.desktop",
            "steam_cachyos_gamescope_session.rc != 0",
            "'multilib' in steam_pacman_repos.stdout_lines",
        ]:
            self.assertIn(required, tasks)

        self.assertIn("exec gamescope --steam -- steam -gamepadui", script)
        self.assertIn("Exec=dotfiles-gamescope-steam-session", desktop)

    def test_role_renames_health_helper_without_legacy_shim(self) -> None:
        tasks = MAIN_TASKS.read_text(encoding="utf-8")
        self.assertIn("files/bin/steam-health", tasks)
        self.assertIn(".local/bin/steam-health", tasks)
        self.assertIn("Remove legacy gaming health helper", tasks)
        self.assertIn(".local/bin/gaming-health", tasks)


    def test_steam_state_scans_extra_libraries_and_proton_runtimes(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            steam = root / "Steam"
            extra = root / "SteamLibrary"
            (steam / "config").mkdir(parents=True)
            (steam / "config/loginusers.vdf").write_text("", encoding="utf-8")
            (steam / "steamapps").mkdir(parents=True)
            (steam / "steamapps/libraryfolders.vdf").write_text(
                f'"libraryfolders"\n{{\n  "1"\n  {{\n    "path" "{extra}"\n  }}\n}}\n',
                encoding="utf-8",
            )
            (extra / "steamapps").mkdir(parents=True)
            (extra / "steamapps/appmanifest_1.acf").write_text("", encoding="utf-8")
            proton = extra / "steamapps/common/Proton Experimental/files/lib/wine/vkd3d-proton/x86_64-windows/d3d12.dll"
            proton.parent.mkdir(parents=True)
            proton.write_text("", encoding="utf-8")

            with patch.object(steam_health, "steam_paths", return_value=[steam]):
                results = list(steam_health.check_steam_state())

        self.assertEqual([result.level for result in results], ["pass", "pass", "pass"])

    def test_gamescope_keepalive_timeout_is_successful_smoke(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:2] == ["vkcube", "--c"]:
                return completed(argv)
            if argv[:4] == ["timeout", "8s", "gamescope", "--keep-alive"]:
                return completed(argv, returncode=124, stdout="[gamescope] launch: Primary child shut down!\n")
            self.fail(f"unexpected command: {argv}")

        with patch.object(steam_health, "command", return_value="/usr/bin/tool"), patch.object(steam_health, "run", side_effect=fake_run):
            results = list(steam_health.check_runtime_smoke())

        self.assertEqual([result.level for result in results], ["pass", "pass"])

    def test_gamescope_start_without_child_completion_is_warning(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:2] == ["vkcube", "--c"]:
                return completed(argv)
            if argv[:4] == ["timeout", "8s", "gamescope", "--keep-alive"]:
                return completed(argv, returncode=124, stdout="[gamescope] [Info] console: gamescope version 3.16.23+\n")
            self.fail(f"unexpected command: {argv}")

        with patch.object(steam_health, "command", return_value="/usr/bin/tool"), patch.object(steam_health, "run", side_effect=fake_run):
            results = list(steam_health.check_runtime_smoke())

        self.assertEqual([result.level for result in results], ["pass", "warn"])

    def test_vkcube_timeout_after_gpu_selection_is_warning(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:2] == ["vkcube", "--c"]:
                return completed(argv, returncode=124, stdout="Selected GPU 0: NVIDIA GeForce RTX 3080\n")
            if argv[:4] == ["timeout", "8s", "gamescope", "--keep-alive"]:
                return completed(argv, returncode=124, stdout="[gamescope] launch: Primary child shut down!\n")
            self.fail(f"unexpected command: {argv}")

        with patch.object(steam_health, "command", return_value="/usr/bin/tool"), patch.object(steam_health, "run", side_effect=fake_run):
            results = list(steam_health.check_runtime_smoke())

        self.assertEqual([result.level for result in results], ["warn", "pass"])

    def test_run_converts_timeout_to_completed_process(self) -> None:
        with patch.object(
            steam_health.subprocess,
            "run",
            side_effect=subprocess.TimeoutExpired(["vkcube"], timeout=1, output=b"partial"),
        ):
            result = steam_health.run(["vkcube"], timeout=1)

        self.assertEqual(result.returncode, 124)
        self.assertEqual(result.stdout, "partial")

    def test_commands_fail_for_missing_required_binaries(self) -> None:
        with patch.object(steam_health, "command", return_value=None):
            results = list(steam_health.check_commands())

        self.assertTrue(results)
        self.assertTrue(all(result.level == "fail" for result in results))
        self.assertIn("steam", results[0].name)

    def test_nvidia_reports_driver_version(self) -> None:
        def fake_run(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
            if argv[:1] == ["nvidia-smi"]:
                return completed(argv, stdout="NVIDIA GeForce RTX 3080, 610.43.02\n")
            self.fail(f"unexpected command: {argv}")

        with (
            patch.object(steam_health, "command", return_value="/usr/bin/nvidia-smi"),
            patch.object(steam_health, "run", side_effect=fake_run),
        ):
            results = list(steam_health.check_nvidia())

        self.assertEqual(results[0].level, "pass")
        self.assertIn("610.43.02", results[0].detail)

    def test_nvidia_drm_passes_when_modeset_is_enabled(self) -> None:
        class FakeModeset:
            def exists(self) -> bool:
                return True

            def read_text(self, encoding: str = "utf-8", errors: str = "replace") -> str:
                return "Y\n"

        with patch.object(steam_health, "Path", return_value=FakeModeset()):
            results = list(steam_health.check_nvidia_drm())

        self.assertEqual(results[0].level, "pass")
        self.assertEqual(results[0].detail, "enabled")


    def test_steam_state_warns_when_login_games_and_proton_are_missing(self) -> None:
        with (
            patch.object(steam_health, "steam_login_files", return_value=[]),
            patch.object(steam_health, "steam_app_manifests", return_value=[]),
            patch.object(steam_health, "proton_dx12_runtime_paths", return_value=[]),
        ):
            results = list(steam_health.check_steam_state())

        self.assertEqual([result.level for result in results], ["warn", "warn", "warn"])
        self.assertIn("sign in", results[0].detail)
        self.assertIn("native/Proton/DX12", results[1].detail)

    def test_strict_mode_fails_on_warnings(self) -> None:
        warning = steam_health.Result("warn", "steam-login-state", "missing")
        with (
            patch.object(steam_health, "collect", return_value=[warning]),
            patch.object(steam_health.sys, "argv", ["steam-health"]),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(steam_health.main(), 0)

        with (
            patch.object(steam_health, "collect", return_value=[warning]),
            patch.object(steam_health.sys, "argv", ["steam-health", "--strict"]),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(steam_health.main(), 2)



if __name__ == "__main__":
    unittest.main()
