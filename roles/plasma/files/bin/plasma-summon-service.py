#!/usr/bin/env python3
"""Session D-Bus launcher/config helper for the Plasma summon KWin script."""
from __future__ import annotations

import argparse
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
    return {
        "apps": load_toml(config_dir / "apps.toml").get("apps", {}),
        "regions": load_toml(config_dir / "regions.toml").get("regions", {}),
        "layouts": load_toml(config_dir / "layouts.toml").get("layouts", {}),
    }


def config_json(config_dir: Path) -> str:
    return json.dumps(load_config(config_dir), sort_keys=True, separators=(",", ":"))


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

    subprocess.Popen(argv, start_new_session=True)
    return f"launched:{app_name}"

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


def build_kdialog_argv(prompt: str, options: list[dict[str, str]]) -> list[str]:
    argv = ["kdialog", "--title", "Plasma Summon", "--menu", prompt]
    for option in options:
        argv.extend([option["id"], option["label"]])
    return argv


def pick_option(prompt: str, options_json: str) -> str:
    options = parse_picker_options(options_json)
    kdialog = shutil.which("kdialog")
    if kdialog:
        argv = build_kdialog_argv(prompt, options)
        argv[0] = kdialog
        result = subprocess.run(argv, check=False, stdout=subprocess.PIPE, text=True)
        return result.stdout.strip() if result.returncode == 0 else ""

    rofi = shutil.which("rofi")
    if rofi:
        labels = [option["label"] for option in options]
        result = subprocess.run(
            [rofi, "-dmenu", "-i", "-p", prompt, "-format", "i"],
            check=False,
            input="\n".join(labels) + "\n",
            stdout=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            return ""
        try:
            index = int(result.stdout.strip())
        except ValueError:
            return ""
        return options[index]["id"] if 0 <= index < len(options) else ""

    return "error:no picker found; install kdialog or rofi"

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
            except (OSError, ValueError) as exc:
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
        except (OSError, ValueError) as exc:
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
