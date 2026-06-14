#!/usr/bin/env python3
"""Session D-Bus launcher/config helper for the Plasma summon KWin script."""
from __future__ import annotations

import argparse
import time
import asyncio
import shutil
import json
import os
import shlex
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import Any

BUS_NAME = "io.techdufus.PlasmaSummon"
BUS_PATH = "/io/techdufus/PlasmaSummon"
BUS_INTERFACE = "io.techdufus.PlasmaSummon"
QT_META = 0x10000000
QT_HYPER = 0x1E000000


def summon_shortcuts() -> list[tuple[list[str], list[int]]]:
    return [
        (
            ["kwin", "Open Plasma Summon Window Mover", "KWin", "Pick region/cell for active window"],
            [QT_META + ord("U")],
        ),
        (
            ["kwin", "Open Plasma Summon Layout Picker", "KWin", "Pick active screen layout"],
            [QT_HYPER + ord("P")],
        ),
    ]


def obsolete_shortcut_names() -> list[str]:
    names = [
        "Cycle Active Screen Layout",
        "Pick Active Window Region",
        "Pick Active Screen Layout",
    ]
    names.extend(f"Move Active to Cell {cell}" for cell in range(1, 7))
    names.extend(
        f"Move Active to Region {region}"
        for region in [
            "bottom_right",
            "center",
            "chat",
            "full",
            "left",
            "main",
            "right",
            "side",
            "top_right",
            "wide",
        ]
    )
    names.extend(
        f"Macro {key} via {prefix}"
        for key in ["a", "s", "e"]
        for prefix in ["CapsLock,CapsLock", "F13,F13", "Launch (5)"]
    )
    return names


async def unregister_obsolete_shortcuts(bus: Any, message_type: Any) -> list[str]:
    removed = []
    for shortcut_name in obsolete_shortcut_names():
        reply = await bus.call(
            message_type(
                destination="org.kde.kglobalaccel",
                path="/kglobalaccel",
                interface="org.kde.KGlobalAccel",
                member="unregister",
                signature="ss",
                body=["kwin", shortcut_name],
            )
        )
        if reply.message_type.name == "ERROR":
            raise RuntimeError(f"{shortcut_name}: {reply.body}")
        if reply.body and reply.body[0]:
            removed.append(shortcut_name)
    return removed


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def default_config_dir() -> Path:
    return config_home() / "plasma-summon"


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def load_config(config_dir: Path) -> dict[str, Any]:
    layout_config = load_toml(config_dir / "layouts.toml")
    return {
        "apps": load_toml(config_dir / "apps.toml").get("apps", {}),
        "regions": load_toml(config_dir / "regions.toml").get("regions", {}),
        "layouts": layout_config.get("layouts", {}),
        "output_layouts": layout_config.get("output_layouts", {}),
    }


def config_json(config_dir: Path) -> str:
    return json.dumps(load_config(config_dir), separators=(",", ":"))


def safe_unit_fragment(value: str) -> str:
    fragment = "".join(ch.lower() if ch.isalnum() else "-" for ch in value)
    fragment = "-".join(part for part in fragment.split("-") if part)
    return fragment[:48] or "process"


def transient_unit_name(kind: str, name: str) -> str:
    return f"plasma-summon-{safe_unit_fragment(kind)}-{safe_unit_fragment(name)}-{os.getpid()}-{time.monotonic_ns()}"


def build_systemd_run_argv(
    systemd_run: str,
    unit_name: str,
    description: str,
    argv: list[str],
) -> list[str]:
    return [
        systemd_run,
        "--user",
        "--collect",
        "--no-block",
        "--quiet",
        "--slice=app.slice",
        "--service-type=exec",
        f"--unit={unit_name}",
        f"--description={description}",
        f"--working-directory={Path.home()}",
        "--",
        *argv,
    ]


def launch_detached(argv: list[str], *, kind: str, name: str) -> None:
    systemd_run = shutil.which("systemd-run")
    if systemd_run:
        unit_name = transient_unit_name(kind, name)
        result = subprocess.run(
            build_systemd_run_argv(systemd_run, unit_name, f"Plasma summon {kind} {name}", argv),
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            message = (result.stderr or result.stdout).strip()
            raise RuntimeError(message or f"systemd-run exited {result.returncode}")
        return

    subprocess.Popen(
        argv,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
    )

def build_launch_argv(apps: dict[str, dict[str, Any]], app_name: str) -> list[str]:
    app = apps.get(app_name)
    if not app:
        raise ValueError(f"Unknown app: {app_name}")

    command = str(app.get("exec", "")).strip()
    if not command:
        raise ValueError(f"App has no exec command: {app_name}")

    argv = shlex.split(command)
    if not argv:
        raise ValueError(f"App has empty exec command: {app_name}")
    return argv


def launch_app(config_dir: Path, app_name: str, *, dry_run: bool = False) -> str:
    apps = load_config(config_dir)["apps"]
    argv = build_launch_argv(apps, app_name)
    if dry_run:
        return " ".join(shlex.quote(part) for part in argv)

    launch_detached(argv, kind="app", name=app_name)
    return f"launched:{app_name}"

def macro_commands() -> dict[str, list[str]]:
    return {
        "screenshot_area": ["spectacle", "--region", "--background", "--copy-image", "--nonotify", "--pointer"],
        "emoji_picker": ["plasma-emojier", "--replace"],
    }


def build_macro_argv(macro_name: str) -> list[str]:
    argv = macro_commands().get(macro_name)
    if not argv:
        raise ValueError(f"Unknown macro: {macro_name}")
    return argv


def run_macro(macro_name: str, *, dry_run: bool = False) -> str:
    argv = build_macro_argv(macro_name)
    if dry_run:
        return " ".join(shlex.quote(part) for part in argv)

    launch_detached(argv, kind="macro", name=macro_name)
    return f"macro:{macro_name}"


def parse_picker_options(options_json: str) -> list[dict[str, str]]:
    raw = json.loads(options_json)
    if not isinstance(raw, list):
        raise ValueError("Picker options must be a list")

    options: list[dict[str, str]] = []
    for item in raw:
        if not isinstance(item, dict):
            raise ValueError("Picker option must be an object")
        option_id = str(item.get("id", "")).strip()
        label = str(item.get("label", "")).strip()
        if not option_id or not label:
            raise ValueError("Picker options require id and label")
        options.append({"id": option_id, "label": label})

    if not options:
        raise ValueError("Picker options cannot be empty")
    return options


FUZZEL_STYLE_ARGS = [
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
]


def fuzzel_placeholder(prompt: str) -> str:
    normalized = prompt.strip().lower()
    if normalized.startswith("layout"):
        return "Type a layout name"
    if normalized.startswith("move"):
        return "Type a cell, region, or app"
    return "Type to filter"


def build_fuzzel_argv(prompt: str) -> list[str]:
    return [
        "fuzzel",
        "--dmenu",
        "--index",
        "--only-match",
        "--minimal-lines",
        "--prompt",
        prompt,
        "--placeholder",
        fuzzel_placeholder(prompt),
        *FUZZEL_STYLE_ARGS,
    ]


def build_rofi_argv(prompt: str) -> list[str]:
    return [
        "rofi",
        "-dmenu",
        "-i",
        "-matching",
        "fuzzy",
        "-no-custom",
        "-p",
        prompt,
        "-format",
        "i",
    ]


def build_kdialog_argv(prompt: str, options: list[dict[str, str]]) -> list[str]:
    argv = ["kdialog", "--title", "Plasma Summon", "--menu", prompt]
    for option in options:
        argv.extend([option["id"], option["label"]])
    return argv


def selected_option_id(options: list[dict[str, str]], output: str) -> str:
    try:
        index = int(output.strip())
    except ValueError:
        return ""
    return options[index]["id"] if 0 <= index < len(options) else ""


def run_index_picker(argv: list[str], options: list[dict[str, str]]) -> str:
    result = subprocess.run(
        argv,
        check=False,
        input="\n".join(option["label"] for option in options) + "\n",
        stdout=subprocess.PIPE,
        text=True,
    )
    return selected_option_id(options, result.stdout) if result.returncode == 0 else ""


def pick_option(prompt: str, options_json: str) -> str:
    options = parse_picker_options(options_json)
    fuzzel = shutil.which("fuzzel")
    if fuzzel:
        argv = build_fuzzel_argv(prompt)
        argv[0] = fuzzel
        return run_index_picker(argv, options)

    rofi = shutil.which("rofi")
    if rofi:
        argv = build_rofi_argv(prompt)
        argv[0] = rofi
        return run_index_picker(argv, options)

    kdialog = shutil.which("kdialog")
    if kdialog:
        argv = build_kdialog_argv(prompt, options)
        argv[0] = kdialog
        result = subprocess.run(argv, check=False, stdout=subprocess.PIPE, text=True)
        return result.stdout.strip() if result.returncode == 0 else ""

    return "error:no picker found; install fuzzel, rofi, or kdialog"

async def configure_shortcuts() -> list[str]:
    try:
        from dbus_next import Message
        from dbus_next.aio import MessageBus
    except ImportError as exc:
        raise SystemExit("python-dbus-next is required for shortcut configuration") from exc

    bus = await MessageBus().connect()
    configured = [f"removed:{name}" for name in await unregister_obsolete_shortcuts(bus, Message)]
    for action_id, keys in summon_shortcuts():
        reply = await bus.call(
            Message(
                destination="org.kde.kglobalaccel",
                path="/kglobalaccel",
                interface="org.kde.KGlobalAccel",
                member="setForeignShortcut",
                signature="asai",
                body=[action_id, keys],
            )
        )
        if reply.message_type.name == "ERROR":
            raise RuntimeError(f"{action_id[1]}: {reply.body}")
        configured.append(action_id[1])
    return configured



async def serve(config_dir: Path) -> None:
    try:
        from dbus_next.aio import MessageBus
        from dbus_next.service import ServiceInterface, method
    except ImportError as exc:
        raise SystemExit("python-dbus-next is required for plasma-summon-service") from exc

    class PlasmaSummon(ServiceInterface):
        def __init__(self) -> None:
            super().__init__(BUS_INTERFACE)

        @method()
        def ConfigJson(self) -> "s":
            return config_json(config_dir)

        @method()
        def LaunchApp(self, app_name: "s") -> "s":
            try:
                return launch_app(config_dir, app_name)
            except (OSError, RuntimeError, ValueError) as exc:
                return f"error:{exc}"

        @method()
        def RunMacro(self, macro_name: "s") -> "s":
            try:
                return run_macro(macro_name)
            except (OSError, RuntimeError, ValueError) as exc:
                return f"error:{exc}"

        @method()
        def PickOption(self, prompt: "s", options_json: "s") -> "s":
            try:
                return pick_option(prompt, options_json)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                return f"error:{exc}"

    bus = await MessageBus().connect()
    bus.export(BUS_PATH, PlasmaSummon())
    await bus.request_name(BUS_NAME)
    await asyncio.get_running_loop().create_future()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Plasma summon D-Bus launcher helper")
    parser.add_argument(
        "--config-dir",
        default=str(default_config_dir()),
        help="directory containing apps.toml, regions.toml, and layouts.toml",
    )
    parser.add_argument("--print-config", action="store_true", help="print config JSON and exit")
    parser.add_argument("--macro", metavar="NAME", help="run a whitelisted desktop macro and exit")
    parser.add_argument("--launch", metavar="APP", help="launch an app from the registry and exit")
    parser.add_argument("--dry-run", action="store_true", help="print launch command instead of executing it")
    parser.add_argument(
        "--configure-shortcuts",
        action="store_true",
        help="apply live KGlobalAccel shortcuts for Plasma summon pickers",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    config_dir = Path(args.config_dir)

    if args.print_config:
        print(config_json(config_dir))
        return 0

    if args.launch:
        try:
            print(launch_app(config_dir, args.launch, dry_run=args.dry_run))
        except (OSError, RuntimeError, ValueError) as exc:
            print(f"error:{exc}", file=sys.stderr)
            return 1
        return 0

    if args.macro:
        try:
            print(run_macro(args.macro, dry_run=args.dry_run))
        except (OSError, RuntimeError, ValueError) as exc:
            print(f"error:{exc}", file=sys.stderr)
            return 1
        return 0


    if args.configure_shortcuts:
        try:
            for name in asyncio.run(configure_shortcuts()):
                print(f"shortcut:{name}")
        except (OSError, RuntimeError) as exc:
            print(f"error:{exc}", file=sys.stderr)
            return 1
        return 0

    asyncio.run(serve(config_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
