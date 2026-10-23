#!/usr/bin/env python3
"""Execute modules/plasma/bin/plasma-summon-service.py without python-dbus-next installed."""
from __future__ import annotations

import asyncio
import importlib.machinery
import importlib.util
import json
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1]
HELPER = MODULE / "bin" / "plasma-summon-service.py"
SUMMON_DIR = MODULE / "summon"


def install_dbus_next_stub() -> None:
    """Provide a recording stand-in for dbus_next when the real package is absent."""
    try:
        import dbus_next  # noqa: F401
        import dbus_next.aio  # noqa: F401
        return
    except ImportError:
        pass

    class Message:
        def __init__(self, **kwargs) -> None:
            self.destination = kwargs["destination"]
            self.path = kwargs["path"]
            self.interface = kwargs["interface"]
            self.member = kwargs["member"]
            self.signature = kwargs["signature"]
            self.body = kwargs["body"]

    class MessageBus:
        async def connect(self):
            raise RuntimeError("dbus_next stub: no real bus")

    package = types.ModuleType("dbus_next")
    aio = types.ModuleType("dbus_next.aio")
    package.Message = Message
    package.aio = aio
    aio.MessageBus = MessageBus
    sys.modules["dbus_next"] = package
    sys.modules["dbus_next.aio"] = aio


install_dbus_next_stub()

loader = importlib.machinery.SourceFileLoader("plasma_summon_service", str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
plasma_summon_service = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = plasma_summon_service
loader.exec_module(plasma_summon_service)


class PlasmaSummonServiceTests(unittest.TestCase):
    def test_helper_loads_config_and_serializes_json_for_kwin(self) -> None:
        config = plasma_summon_service.load_config(SUMMON_DIR)
        self.assertEqual(
            {name: config["apps"][name]["key"] for name in ["terminal", "signal"]},
            {"terminal": "t", "signal": "C"},
        )
        self.assertEqual(config["regions"]["main"]["w"], "65%")
        self.assertEqual(config["layouts"]["fourk"]["apps"]["browser"], 2)
        self.assertNotIn("default_region", config["layouts"]["fourk"])
        self.assertEqual(config["output_layouts"], {})

        payload = json.loads(plasma_summon_service.config_json(SUMMON_DIR))
        self.assertEqual(list(payload["layouts"]), ["standard", "fourk", "hd", "full"])
        self.assertEqual(payload["apps"]["files"]["exec"], "dolphin")
        self.assertNotIn("key", payload["apps"]["steam"])
        self.assertEqual(payload["output_layouts"], {})
        self.assertNotIn("default_region", payload["layouts"]["standard"])

    def test_helper_launch_argv_is_whitelisted_by_app_registry(self) -> None:
        apps = plasma_summon_service.load_config(SUMMON_DIR)["apps"]
        self.assertEqual(plasma_summon_service.build_launch_argv(apps, "terminal"), ["ghostty"])
        self.assertEqual(plasma_summon_service.build_launch_argv(apps, "signal"), ["signal-desktop"])
        with self.assertRaises(ValueError):
            plasma_summon_service.build_launch_argv(apps, "missing")

    def test_helper_launch_argv_selects_available_exec_candidate(self) -> None:
        apps = {
            "browser": {
                "exec": [
                    "brave --new-window",
                    "/usr/bin/flatpak run com.brave.Browser",
                ],
            },
        }

        def native_brave_only(binary: str) -> str | None:
            return "/usr/bin/brave" if binary == "brave" else None

        with patch.object(plasma_summon_service.shutil, "which", side_effect=native_brave_only):
            self.assertEqual(
                plasma_summon_service.build_launch_argv(apps, "browser"),
                ["brave", "--new-window"],
            )

        with (
            patch.object(plasma_summon_service.shutil, "which", return_value=None),
            patch.object(plasma_summon_service.os.path, "isfile", return_value=True),
            patch.object(plasma_summon_service.os, "access", return_value=True),
            patch.object(
                plasma_summon_service.subprocess,
                "run",
                return_value=plasma_summon_service.subprocess.CompletedProcess(args=[], returncode=0),
            ),
        ):
            self.assertEqual(
                plasma_summon_service.build_launch_argv(apps, "browser"),
                ["/usr/bin/flatpak", "run", "com.brave.Browser"],
            )

        with (
            patch.object(plasma_summon_service.shutil, "which", return_value=None),
            patch.object(plasma_summon_service.os.path, "isfile", return_value=True),
            patch.object(plasma_summon_service.os, "access", return_value=True),
            patch.object(
                plasma_summon_service.subprocess,
                "run",
                return_value=plasma_summon_service.subprocess.CompletedProcess(args=[], returncode=1),
            ),
        ):
            with self.assertRaisesRegex(ValueError, "No available exec candidate for app browser"):
                plasma_summon_service.build_launch_argv(apps, "browser")

    def test_helper_dry_run_shell_quotes_selected_exec_candidate(self) -> None:
        apps = {"browser": {"exec": ["brave --profile-directory='Default User'"]}}
        with (
            patch.object(plasma_summon_service, "load_config", return_value={"apps": apps}),
            patch.object(plasma_summon_service.shutil, "which", return_value="/usr/bin/brave"),
        ):
            self.assertEqual(
                plasma_summon_service.launch_app(Path("/unused"), "browser", dry_run=True),
                "brave '--profile-directory=Default User'",
            )

    def test_helper_dry_run_does_not_spawn_processes(self) -> None:
        self.assertEqual(
            plasma_summon_service.launch_app(SUMMON_DIR, "terminal", dry_run=True),
            "ghostty",
        )

    def test_helper_launches_apps_through_independent_systemd_unit(self) -> None:
        completed = plasma_summon_service.subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="",
            stderr="",
        )
        with (
            patch.object(plasma_summon_service.shutil, "which", return_value="/usr/bin/systemd-run"),
            patch.object(plasma_summon_service.os, "getpid", return_value=1234),
            patch.object(plasma_summon_service.time, "monotonic_ns", return_value=5678),
            patch.object(plasma_summon_service.subprocess, "run", return_value=completed) as run,
            patch.object(plasma_summon_service.subprocess, "Popen") as popen,
        ):
            self.assertEqual(
                plasma_summon_service.launch_app(SUMMON_DIR, "terminal"),
                "launched:terminal",
            )

        popen.assert_not_called()
        argv = run.call_args.args[0]
        self.assertEqual(argv[0], "/usr/bin/systemd-run")
        self.assertIn("--user", argv)
        self.assertIn("--collect", argv)
        self.assertIn("--no-block", argv)
        self.assertIn("--slice=app.slice", argv)
        self.assertIn("--service-type=exec", argv)
        self.assertIn("--unit=plasma-summon-app-terminal-1234-5678", argv)
        self.assertEqual(argv[-2:], ["--", "ghostty"])
        self.assertIs(run.call_args.kwargs["stdin"], plasma_summon_service.subprocess.DEVNULL)
        self.assertIs(run.call_args.kwargs["stdout"], plasma_summon_service.subprocess.PIPE)
        self.assertIs(run.call_args.kwargs["stderr"], plasma_summon_service.subprocess.PIPE)

    def test_helper_fallback_launch_detaches_stdio_from_service(self) -> None:
        with (
            patch.object(plasma_summon_service.shutil, "which", return_value=None),
            patch.object(plasma_summon_service.subprocess, "Popen") as popen,
        ):
            self.assertEqual(
                plasma_summon_service.launch_app(SUMMON_DIR, "terminal"),
                "launched:terminal",
            )

        popen.assert_called_once_with(
            ["ghostty"],
            stdin=plasma_summon_service.subprocess.DEVNULL,
            stdout=plasma_summon_service.subprocess.DEVNULL,
            stderr=plasma_summon_service.subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )

    def test_helper_builds_safe_picker_arguments(self) -> None:
        options = plasma_summon_service.parse_picker_options(
            '[{"id":"cell:1","label":"1  main (terminal)"},{"id":"cell:2","label":"2  side (browser)"}]'
        )
        self.assertEqual(options[0]["id"], "cell:1")
        self.assertEqual(
            plasma_summon_service.build_fuzzel_argv("Move window"),
            [
                "fuzzel",
                "--dmenu",
                "--index",
                "--only-match",
                "--minimal-lines",
                "--prompt",
                "Move window",
                "--placeholder",
                "Type a cell, region, or app",
                "--match-mode",
                "fzf",
                "--font",
                "sans:size=13",
                "--use-bold",
                "--anchor",
                "center",
                "--layer",
                "overlay",
                "--width",
                "64",
                "--lines",
                "10",
                "--horizontal-pad",
                "28",
                "--vertical-pad",
                "16",
                "--inner-pad",
                "10",
                "--line-height",
                "24",
                "--background-color",
                "1e1e2eff",
                "--text-color",
                "cdd6f4ff",
                "--prompt-color",
                "89b4faff",
                "--placeholder-color",
                "6c7086ff",
                "--input-color",
                "f5e0dcff",
                "--match-color",
                "f38ba8ff",
                "--selection-color",
                "313244ff",
                "--selection-text-color",
                "cdd6f4ff",
                "--selection-match-color",
                "fab387ff",
                "--counter-color",
                "6c7086ff",
                "--border-width",
                "2",
                "--border-radius",
                "18",
                "--border-color",
                "89b4faff",
                "--selection-radius",
                "10",
                "--counter",
            ],
        )
        self.assertEqual(
            plasma_summon_service.build_rofi_argv("Move window"),
            [
                "rofi",
                "-dmenu",
                "-i",
                "-matching",
                "fuzzy",
                "-no-custom",
                "-p",
                "Move window",
                "-format",
                "i",
            ],
        )
        self.assertEqual(
            plasma_summon_service.selected_option_id(options, "1\n"),
            "cell:2",
        )
        self.assertEqual(
            plasma_summon_service.selected_option_id(options, "missing\n"),
            "",
        )
        self.assertEqual(
            plasma_summon_service.build_kdialog_argv("Move window", options),
            [
                "kdialog",
                "--title",
                "Plasma Summon",
                "--menu",
                "Move window",
                "cell:1",
                "1  main (terminal)",
                "cell:2",
                "2  side (browser)",
            ],
        )

        with self.assertRaises(ValueError):
            plasma_summon_service.parse_picker_options("[]")
        self.assertEqual(
            plasma_summon_service.fuzzel_placeholder("Layout"),
            "Type a layout name",
        )

    def test_helper_prefers_fuzzy_picker_backend(self) -> None:
        options_json = (
            '[{"id":"cell:1","label":"1  main (terminal)"},'
            '{"id":"cell:2","label":"2  side (browser)"}]'
        )
        completed = plasma_summon_service.subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="1\n",
        )

        def which(binary: str) -> str | None:
            return "/usr/bin/fuzzel" if binary == "fuzzel" else None

        with (
            patch.object(plasma_summon_service.shutil, "which", side_effect=which),
            patch.object(plasma_summon_service.subprocess, "run", return_value=completed) as run,
        ):
            self.assertEqual(
                plasma_summon_service.pick_option("Move window", options_json),
                "cell:2",
            )

        argv = run.call_args.args[0]
        self.assertEqual(argv[0], "/usr/bin/fuzzel")
        self.assertIn("--index", argv)
        self.assertIn("--only-match", argv)
        self.assertEqual(
            run.call_args.kwargs["input"],
            "1  main (terminal)\n2  side (browser)\n",
        )
        self.assertIn("--match-mode", argv)
        self.assertIn("fzf", argv)
        self.assertIn("--border-radius", argv)
        self.assertIn("1e1e2eff", argv)

    def test_helper_runs_whitelisted_desktop_macros(self) -> None:
        self.assertEqual(
            plasma_summon_service.build_macro_argv("screenshot_area"),
            ["spectacle", "--region", "--background", "--copy-image", "--nonotify", "--pointer"],
        )
        emoji_argv = plasma_summon_service.build_macro_argv("emoji_picker")
        self.assertEqual(emoji_argv, ["rofimoji"])
        self.assertNotIn("plasma-emojier", " ".join(emoji_argv))
        self.assertEqual(
            plasma_summon_service.run_macro("emoji_picker", dry_run=True),
            "rofimoji",
        )
        with self.assertRaises(ValueError):
            plasma_summon_service.build_macro_argv("missing")

    def test_helper_defines_runtime_picker_shortcuts(self) -> None:
        shortcuts = plasma_summon_service.summon_shortcuts()
        self.assertEqual(
            shortcuts,
            [
                (
                    ["kwin", "Open Plasma Summon Window Mover", "KWin", "Pick region/cell for active window"],
                    [0x10000000 + ord("U")],
                ),
                (
                    ["kwin", "Hide Active Window", "KWin", "Minimize active window"],
                    [0x10000000 + ord("H")],
                ),
                (
                    ["kwin", "Open Plasma Summon Layout Picker", "KWin", "Pick active screen layout"],
                    [0x1E000000 + ord("P")],
                ),
            ],
        )

    def test_helper_encodes_app_shortcuts_for_all_prefixes_and_key_cases(self) -> None:
        apps = {
            "terminal": {"key": "t"},
            "grokbot": {"key": "G"},
            "signal": {"key": "C"},
            "steam": {"exec": "steam"},
        }
        prefixes = [
            ("F13", 0x0100003C),
            ("CapsLock", 0x01000024),
            ("Tools", 0x010000F1),
        ]
        expected = []
        for app_name, letter in [
            ("terminal", ord("T")),
            ("grokbot", 0x02000000 + ord("G")),
            ("signal", 0x02000000 + ord("C")),
        ]:
            for prefix, prefix_code in prefixes:
                expected.append(
                    (
                        ["kwin", f"Summon {app_name} via {prefix}", "KWin", f"Summon {app_name}"],
                        [prefix_code, letter, 0, 0],
                    )
                )

        self.assertEqual(plasma_summon_service.app_shortcuts(apps), expected)

    def test_helper_releases_unbound_app_actions_before_migrating_terminal_key(self) -> None:
        class FakeBus:
            def __init__(self) -> None:
                self.calls = []

            async def call(self, message):
                # The real dbus_next Message validates and marshals; the stub only records.
                if hasattr(message, "signature_tree"):
                    message.signature_tree.verify(message.body)
                    message._marshall()
                self.calls.append(message)
                return types.SimpleNamespace(
                    message_type=types.SimpleNamespace(name="METHOD_RETURN"),
                    body=[False],
                )

            def disconnect(self) -> None:
                pass

        fake_bus = FakeBus()

        class FakeMessageBus:
            async def connect(self) -> FakeBus:
                return fake_bus

        with patch("dbus_next.aio.MessageBus", FakeMessageBus):
            asyncio.run(plasma_summon_service.configure_shortcuts(SUMMON_DIR))

        first_calls = list(fake_bus.calls)
        steam_actions = {
            f"Summon steam via {prefix}" for prefix in ["F13", "CapsLock", "Tools"]
        }
        steam_release_indices = [
            index
            for index, message in enumerate(first_calls)
            if message.member == "unregister"
            and len(message.body) == 2
            and message.body[0] == "kwin"
            and message.body[1] in steam_actions
        ]
        self.assertEqual(len(steam_release_indices), 3)

        first_app_assignments = [
            (message.signature, message.body)
            for message in first_calls
            if message.member == "setForeignShortcutKeys"
        ]
        terminal_updates = [
            (index, message)
            for index, message in enumerate(first_calls)
            if message.member == "setForeignShortcutKeys"
            and message.body[0][1].startswith("Summon terminal via ")
        ]
        self.assertEqual(len(terminal_updates), 3)
        self.assertLess(max(steam_release_indices), min(index for index, _ in terminal_updates))

        f13_terminal_update = next(
            message
            for _, message in terminal_updates
            if message.body[0][1] == "Summon terminal via F13"
        )
        self.assertEqual(f13_terminal_update.signature, "asa(ai)")
        self.assertEqual(
            f13_terminal_update.body,
            [
                ["kwin", "Summon terminal via F13", "KWin", "Summon terminal"],
                [[[0x0100003C, ord("T"), 0, 0]]],
            ],
        )

        fake_bus.calls.clear()
        with patch("dbus_next.aio.MessageBus", FakeMessageBus):
            asyncio.run(plasma_summon_service.configure_shortcuts(SUMMON_DIR))
        self.assertEqual(
            [
                (message.signature, message.body)
                for message in fake_bus.calls
                if message.member == "setForeignShortcutKeys"
            ],
            first_app_assignments,
        )

    def test_helper_cli_passes_config_dir_to_shortcut_configuration(self) -> None:
        configured_dirs = []

        async def configure_shortcuts(config_dir: Path | None = None) -> list[str]:
            configured_dirs.append(config_dir)
            return []

        with patch.object(plasma_summon_service, "configure_shortcuts", configure_shortcuts):
            self.assertEqual(
                plasma_summon_service.main(
                    ["--config-dir", str(SUMMON_DIR), "--configure-shortcuts"]
                ),
                0,
            )
        self.assertEqual(configured_dirs, [SUMMON_DIR])

    def test_helper_declares_obsolete_picker_conflicts(self) -> None:
        obsolete = plasma_summon_service.obsolete_shortcut_names()
        for name in [
            "Move Active to Cell 1",
            "Move Active to Region main",
            "Cycle Active Screen Layout",
            "Pick Active Window Region",
            "Pick Active Screen Layout",
        ]:
            self.assertIn(name, obsolete)
        for name in [
            "Macro a via F13,F13",
            "Macro e via CapsLock,CapsLock",
            "Macro s via Launch (5)",
            "Macro g via F16",
            "Macro g via XF86Launch5",
            "Macro g via Tools,Tools",
        ]:
            self.assertIn(name, obsolete)


if __name__ == "__main__":
    unittest.main()
