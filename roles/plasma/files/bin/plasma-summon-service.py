#!/usr/bin/env python3
"""Session D-Bus launcher/config helper for the Plasma summon KWin script."""
from __future__ import annotations

import argparse
import asyncio
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

    asyncio.run(serve(config_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
