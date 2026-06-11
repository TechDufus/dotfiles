#!/usr/bin/env python3
"""Hyprland summon and region helper.

The helper is intentionally stdlib-only so the dotfiles can bootstrap it before
language-specific package managers are configured.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


WINDOW_MATCH_FIELDS = ("class", "initialClass", "app_id", "initialTitle", "title")


@dataclass(frozen=True)
class CommandResult:
    args: tuple[str, ...]
    returncode: int
    stdout: str


class HyprCtlError(RuntimeError):
    pass


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def runtime_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR")
    if base:
        return Path(base)
    return Path("/tmp") / f"hypr-summon-{os.getuid()}"


def default_config_dir() -> Path:
    return config_home() / "hypr" / "summon"


def state_path() -> Path:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "default")
    return runtime_dir() / f"hypr-summon-{signature}.json"


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def run_hyprctl(*args: str, dry_run: bool = False) -> CommandResult:
    command = ("hyprctl", *args)
    if dry_run:
        print(" ".join(command))
        return CommandResult(command, 0, "")

    completed = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise HyprCtlError(f"hyprctl {' '.join(args)} failed: {detail}")
    return CommandResult(command, completed.returncode, completed.stdout)


def lua_string(value: Any) -> str:
    return json.dumps(str(value))


def lua_scalar(value: Any) -> str:
    text = str(value)
    if text.isdecimal():
        return text
    return lua_string(text)


def window_selector(client: dict[str, Any]) -> str:
    target = address(client)
    if not target:
        raise HyprCtlError("cannot target window without address")
    return f"address:{target}"


def dispatch_lua(expression: str, dry_run: bool = False) -> CommandResult:
    return run_hyprctl("dispatch", expression, dry_run=dry_run)


def hyprctl_json(*args: str) -> Any:
    result = run_hyprctl("-j", *args)
    text = result.stdout.strip()
    if not text:
        return {}
    return json.loads(text)


def load_state(path: Path | None = None) -> dict[str, Any]:
    target = path or state_path()
    try:
        with target.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }
    except json.JSONDecodeError:
        return {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }

    if not isinstance(data, dict):
        return {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }
    data.setdefault("last_by_app", {})
    data.setdefault("last_region_by_address", {})
    data.setdefault("last_cell_by_address", {})
    data.setdefault("layout_by_monitor", {})
    data.setdefault("app_cell_overrides", {})
    return data


def save_state(state: dict[str, Any], path: Path | None = None) -> None:
    target = path or state_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(target.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, sort_keys=True)
        handle.write("\n")
    tmp.replace(target)


def casefold(value: Any) -> str:
    return str(value or "").casefold()


def parse_selector(selector: str) -> tuple[str, str]:
    if ":" not in selector:
        raise ValueError(f"invalid match selector {selector!r}; expected field:value")
    field, expected = selector.split(":", 1)
    field = field.strip()
    expected = expected.strip()
    if field not in WINDOW_MATCH_FIELDS:
        raise ValueError(f"unsupported match field {field!r}")
    if not expected:
        raise ValueError(f"empty match value in selector {selector!r}")
    return field, expected


def client_value(client: dict[str, Any], field: str) -> str:
    if field == "app_id":
        return str(client.get("app_id") or client.get("class") or "")
    return str(client.get(field) or "")


def selector_matches(client: dict[str, Any], selector: str) -> bool:
    field, expected = parse_selector(selector)
    actual = client_value(client, field)
    if field in ("title", "initialTitle"):
        return casefold(expected) in casefold(actual)
    return casefold(actual) == casefold(expected)


def client_matches(client: dict[str, Any], app_config: dict[str, Any]) -> bool:
    selectors = app_config.get("match") or []
    if isinstance(selectors, str):
        selectors = [selectors]
    return any(selector_matches(client, selector) for selector in selectors)


def app_for_client(apps: dict[str, dict[str, Any]], client: dict[str, Any] | None) -> str | None:
    if not client:
        return None
    for name, app_config in apps.items():
        if client_matches(client, app_config):
            return name
    return None


def address(client: dict[str, Any] | None) -> str | None:
    if not client:
        return None
    raw = client.get("address")
    return str(raw) if raw else None


def client_by_address(clients: Iterable[dict[str, Any]], wanted: str | None) -> dict[str, Any] | None:
    if not wanted:
        return None
    normalized = casefold(wanted)
    for client in clients:
        if casefold(address(client)) == normalized:
            return client
    return None


def workspace_id(client: dict[str, Any] | None) -> int | str | None:
    workspace = (client or {}).get("workspace")
    if isinstance(workspace, dict):
        return workspace.get("id") or workspace.get("name")
    return None


def monitor_id(client: dict[str, Any] | None) -> int | None:
    value = (client or {}).get("monitor")
    return value if isinstance(value, int) else None



def monitor_dispatch_target(monitors: list[dict[str, Any]], wanted: Any) -> Any:
    text = str(wanted)
    if text.startswith(("+", "-")):
        return text
    for monitor in monitors:
        if text in {str(monitor.get("name") or ""), str(monitor.get("description") or "")}:
            return monitor.get("id", wanted)
    return wanted

def best_client(
    clients: list[dict[str, Any]],
    app_name: str,
    app_config: dict[str, Any],
    active: dict[str, Any] | None,
    state: dict[str, Any],
) -> dict[str, Any] | None:
    matches = [client for client in clients if client_matches(client, app_config)]
    if not matches:
        return None

    remembered = client_by_address(matches, state.get("last_by_app", {}).get(app_name))
    if remembered:
        return remembered

    active_monitor = monitor_id(active)
    active_workspace = workspace_id(active)

    def score(client: dict[str, Any]) -> tuple[int, int, str]:
        same_monitor = int(active_monitor is not None and monitor_id(client) == active_monitor)
        same_workspace = int(active_workspace is not None and workspace_id(client) == active_workspace)
        return (same_monitor, same_workspace, address(client) or "")

    return max(matches, key=score)


def app_places_client(app_config: dict[str, Any], args: argparse.Namespace) -> bool:
    if getattr(args, "no_place", False):
        return False
    if getattr(args, "place", False):
        return True
    return bool(app_config.get("place", False))


def app_places_launched_client(app_config: dict[str, Any], args: argparse.Namespace) -> bool:
    if getattr(args, "no_place", False):
        return False
    if getattr(args, "place", False):
        return True
    return bool(app_config.get("place", bool(app_config.get("region") or app_config.get("monitor"))))


def place_app_client(
    app_name: str,
    app_config: dict[str, Any],
    client: dict[str, Any],
    config_dir: Path,
    *,
    dry_run: bool = False,
    force: bool = False,
    require_place: bool = False,
) -> bool:
    region_name = app_config.get("region")
    monitor_name = app_config.get("monitor")
    if not region_name and not monitor_name:
        return False
    if client.get("fullscreen") and not force:
        if require_place:
            raise SystemExit("refusing to place fullscreen window without --force")
        return False

    if monitor_name:
        dispatch_focus(client, dry_run=dry_run)
        monitors = hyprctl_json("monitors")
        if not isinstance(monitors, list):
            monitors = []
        monitor_target = monitor_dispatch_target(monitors, monitor_name)
        dispatch_lua(
            f"hl.dsp.window.move({{ monitor = {lua_scalar(monitor_target)}, window = {lua_string(window_selector(client))} }})",
            dry_run=dry_run,
        )
        if not dry_run:
            refreshed = hyprctl_json("activewindow")
            if isinstance(refreshed, dict) and address(refreshed):
                client = refreshed

    if not region_name:
        return True

    regions = load_regions(config_dir)
    region = regions.get(region_name)
    if not region:
        raise SystemExit(f"unknown region {region_name!r} for app {app_name!r}")

    monitors = hyprctl_json("monitors")
    if not isinstance(monitors, list):
        monitors = []
    apply_region(region, client, monitors, dry_run=dry_run)
    return True


def wait_for_matching_client(
    app_config: dict[str, Any],
    known_addresses: set[str],
    *,
    timeout: float,
    interval: float = 0.25,
) -> dict[str, Any] | None:
    deadline = time.monotonic() + timeout
    while True:
        clients = hyprctl_json("clients")
        if isinstance(clients, list):
            matches = [
                client for client in clients
                if client_matches(client, app_config)
                and address(client) not in known_addresses
            ]
            if matches:
                return max(matches, key=lambda client: address(client) or "")

        if time.monotonic() >= deadline:
            return None
        time.sleep(interval)


def dispatch_focus(client: dict[str, Any], dry_run: bool = False) -> None:
    dispatch_lua(
        f"hl.dsp.focus({{ window = {lua_string(window_selector(client))} }})",
        dry_run=dry_run,
    )


def launch(command: str, dry_run: bool = False) -> None:
    if dry_run:
        print(command)
        return
    subprocess.Popen(command, shell=True, start_new_session=True)


def coerce_dimension(raw: Any, total: int) -> int:
    if isinstance(raw, str) and raw.endswith("%"):
        return round(total * (float(raw[:-1]) / 100.0))
    if isinstance(raw, float) and 0 <= raw <= 1:
        return round(total * raw)
    return int(raw)


def monitor_for_window(monitors: list[dict[str, Any]], client: dict[str, Any] | None) -> dict[str, Any]:
    wanted_id = monitor_id(client)
    if wanted_id is not None:
        for monitor in monitors:
            if monitor.get("id") == wanted_id:
                return monitor
    for monitor in monitors:
        if monitor.get("focused"):
            return monitor
    if not monitors:
        raise HyprCtlError("hyprctl monitors returned no active monitors")
    return monitors[0]


def monitor_logical_size(monitor: dict[str, Any]) -> tuple[int, int]:
    width = int(monitor["width"])
    height = int(monitor["height"])
    try:
        scale = float(monitor.get("scale") or 1)
    except (TypeError, ValueError):
        scale = 1.0
    if scale <= 0:
        scale = 1.0
    return max(1, round(width / scale)), max(1, round(height / scale))


def region_geometry(region: dict[str, Any], monitor: dict[str, Any]) -> tuple[int, int, int, int]:
    width, height = monitor_logical_size(monitor)
    local_x = coerce_dimension(region.get("x", 0), width)
    local_y = coerce_dimension(region.get("y", 0), height)
    if local_x < 0 or local_x >= width or local_y < 0 or local_y >= height:
        raise ValueError("region origin is outside monitor bounds")

    w = coerce_dimension(region["w"], width)
    h = coerce_dimension(region["h"], height)
    if w <= 0 or h <= 0:
        raise ValueError("region dimensions must be positive")

    w = min(w, width - local_x)
    h = min(h, height - local_y)
    x = int(monitor.get("x", 0)) + local_x
    y = int(monitor.get("y", 0)) + local_y
    return x, y, w, h




def client_outside_monitor_bounds(client: dict[str, Any], monitors: list[dict[str, Any]]) -> bool:
    monitor = monitor_for_window(monitors, client)
    width, height = monitor_logical_size(monitor)
    origin_x = int(monitor.get("x", 0))
    origin_y = int(monitor.get("y", 0))
    at = client.get("at")
    size = client.get("size")
    if not isinstance(at, list) or not isinstance(size, list) or len(at) < 2 or len(size) < 2:
        return False

    left = int(at[0])
    top = int(at[1])
    window_width = int(size[0])
    window_height = int(size[1])
    return (
        window_width > width
        or window_height > height
        or left < origin_x
        or top < origin_y
        or left + window_width > origin_x + width
        or top + window_height > origin_y + height
    )


def app_needs_placement_repair(app_config: dict[str, Any], client: dict[str, Any]) -> bool:
    if client.get("fullscreen") or not (app_config.get("region") or app_config.get("monitor")):
        return False
    monitors = hyprctl_json("monitors")
    if not isinstance(monitors, list):
        return False

    monitor_name = app_config.get("monitor")
    if monitor_name:
        current = monitor_for_window(monitors, client)
        desired = monitor_dispatch_target(monitors, monitor_name)
        if desired != current.get("id") and desired != current.get("name"):
            return True

    return client_outside_monitor_bounds(client, monitors)


def apply_geometry_on_monitor(
    client: dict[str, Any],
    monitor: dict[str, Any],
    local_x: int,
    local_y: int,
    width: int,
    height: int,
    *,
    dry_run: bool = False,
) -> None:
    selector = window_selector(client)
    x = int(monitor.get("x", 0)) + local_x
    y = int(monitor.get("y", 0)) + local_y
    dispatch_lua(
        f"hl.dsp.window.float({{ action = \"enable\", window = {lua_string(selector)} }})",
        dry_run=dry_run,
    )
    dispatch_lua(
        f"hl.dsp.window.resize({{ x = {width}, y = {height}, relative = false, window = {lua_string(selector)} }})",
        dry_run=dry_run,
    )
    dispatch_lua(
        f"hl.dsp.window.move({{ x = {x}, y = {y}, relative = false, window = {lua_string(selector)} }})",
        dry_run=dry_run,
    )


def apply_region_on_monitor(
    region: dict[str, Any],
    client: dict[str, Any],
    monitor: dict[str, Any],
    *,
    dry_run: bool = False,
) -> None:
    x, y, w, h = region_geometry(region, monitor)
    selector = window_selector(client)

    if region.get("float", True):
        dispatch_lua(
            f"hl.dsp.window.float({{ action = \"enable\", window = {lua_string(selector)} }})",
            dry_run=dry_run,
        )
    dispatch_lua(
        f"hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = {lua_string(selector)} }})",
        dry_run=dry_run,
    )
    dispatch_lua(
        f"hl.dsp.window.move({{ x = {x}, y = {y}, relative = false, window = {lua_string(selector)} }})",
        dry_run=dry_run,
    )


def apply_region(
    region: dict[str, Any],
    client: dict[str, Any],
    monitors: list[dict[str, Any]],
    *,
    dry_run: bool = False,
) -> None:
    apply_region_on_monitor(
        region,
        client,
        monitor_for_window(monitors, client),
        dry_run=dry_run,
    )


def load_apps(config_dir: Path) -> dict[str, dict[str, Any]]:
    data = load_toml(config_dir / "apps.toml")
    apps = data.get("apps", {})
    if not isinstance(apps, dict):
        raise ValueError("apps.toml must contain [apps.<name>] tables")
    return {str(name): dict(config) for name, config in apps.items()}


def load_regions(config_dir: Path) -> dict[str, dict[str, Any]]:
    data = load_toml(config_dir / "regions.toml")
    regions = data.get("regions", {})
    if not isinstance(regions, dict):
        raise ValueError("regions.toml must contain [regions.<name>] tables")
    return {str(name): dict(config) for name, config in regions.items()}

def load_layouts(config_dir: Path) -> dict[str, dict[str, Any]]:
    data = load_toml(config_dir / "layouts.toml")
    layouts = data.get("layouts", {})
    if not isinstance(layouts, dict):
        raise ValueError("layouts.toml must contain [layouts.<name>] tables")
    return {str(name): dict(config) for name, config in layouts.items()}



def monitor_key(monitor: dict[str, Any]) -> str:
    return str(monitor.get("name") or monitor.get("id") or "")


def sorted_monitors(monitors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        monitors,
        key=lambda monitor: (
            int(monitor.get("x", 0)),
            int(monitor.get("y", 0)),
            int(monitor.get("id", 0)),
        ),
    )


def other_monitor_for_client(
    monitors: list[dict[str, Any]],
    client: dict[str, Any],
    *,
    direction: int = 1,
) -> dict[str, Any]:
    ordered = sorted_monitors(monitors)
    if len(ordered) < 2:
        raise SystemExit("no other monitor is available")

    current = monitor_for_window(ordered, client)
    current_key = monitor_key(current)
    for index, monitor in enumerate(ordered):
        if monitor_key(monitor) == current_key:
            return ordered[(index + direction) % len(ordered)]
    return ordered[0]


def layout_names(layouts: dict[str, dict[str, Any]]) -> list[str]:
    names = list(layouts)
    if not names:
        raise SystemExit("no layouts configured")
    return names


def layout_for_monitor(
    layouts: dict[str, dict[str, Any]],
    state: dict[str, Any],
    monitor: dict[str, Any],
) -> tuple[str, dict[str, Any]]:
    key = monitor_key(monitor)
    configured = state.setdefault("layout_by_monitor", {}).get(key)
    if configured in layouts:
        return configured, layouts[configured]

    width, _ = monitor_logical_size(monitor)
    for name, layout in layouts.items():
        min_width = int(layout.get("min_width", 0))
        max_width = layout.get("max_width")
        if width < min_width:
            continue
        if max_width is not None and width > int(max_width):
            continue
        return name, layout

    name = layout_names(layouts)[0]
    return name, layouts[name]


def set_layout_for_monitor(
    state: dict[str, Any],
    monitor: dict[str, Any],
    layout_name: str,
) -> None:
    state.setdefault("layout_by_monitor", {})[monitor_key(monitor)] = layout_name


def app_cell_override_key(monitor: dict[str, Any], layout_name: str, app_name: str) -> str:
    return f"{monitor_key(monitor)}:{layout_name}:{app_name}"


def layout_cell_name(layout: dict[str, Any], cell_index: int) -> str:
    cells = layout.get("cells") or []
    if not isinstance(cells, list):
        raise SystemExit("layout cells must be a list")
    if cell_index < 1 or cell_index > len(cells):
        raise SystemExit(f"layout has no cell {cell_index}")
    return str(cells[cell_index - 1])


def configured_app_cell(
    app_name: str | None,
    layout_name: str,
    layout: dict[str, Any],
    state: dict[str, Any],
    monitor: dict[str, Any],
) -> int | None:
    if not app_name:
        return None
    overrides = state.setdefault("app_cell_overrides", {})
    override = overrides.get(app_cell_override_key(monitor, layout_name, app_name))
    if override is not None:
        return int(override)

    apps = layout.get("apps") or {}
    if not isinstance(apps, dict) or app_name not in apps:
        return None
    return int(apps[app_name])


def apply_cell_on_monitor(
    client: dict[str, Any],
    monitor: dict[str, Any],
    cell_index: int,
    apps: dict[str, dict[str, Any]],
    regions: dict[str, dict[str, Any]],
    layouts: dict[str, dict[str, Any]],
    state: dict[str, Any],
    *,
    persist_override: bool = False,
    dry_run: bool = False,
) -> None:
    layout_name, layout = layout_for_monitor(layouts, state, monitor)
    cell_name = layout_cell_name(layout, cell_index)
    region = regions.get(cell_name)
    if not region:
        raise SystemExit(f"layout {layout_name!r} references unknown region {cell_name!r}")

    app_name = app_for_client(apps, client)
    if persist_override and app_name:
        state.setdefault("app_cell_overrides", {})[
            app_cell_override_key(monitor, layout_name, app_name)
        ] = cell_index
    if address(client):
        state.setdefault("last_cell_by_address", {})[address(client)] = cell_index

    apply_region_on_monitor(region, client, monitor, dry_run=dry_run)


def reapply_layout_on_monitor(
    monitor: dict[str, Any],
    apps: dict[str, dict[str, Any]],
    regions: dict[str, dict[str, Any]],
    layouts: dict[str, dict[str, Any]],
    state: dict[str, Any],
    *,
    dry_run: bool = False,
    force: bool = False,
) -> None:
    clients = hyprctl_json("clients")
    if not isinstance(clients, list):
        return
    target_id = monitor.get("id")
    layout_name, layout = layout_for_monitor(layouts, state, monitor)
    for client in clients:
        if monitor_id(client) != target_id:
            continue
        if client.get("fullscreen") and not force:
            continue
        app_name = app_for_client(apps, client)
        cell_index = configured_app_cell(app_name, layout_name, layout, state, monitor)
        if cell_index is not None:
            apply_cell_on_monitor(
                client,
                monitor,
                cell_index,
                apps,
                regions,
                layouts,
                state,
                dry_run=dry_run,
            )


def move_window_to_monitor(
    client: dict[str, Any],
    monitor: dict[str, Any],
    monitors: list[dict[str, Any]],
    *,
    dry_run: bool = False,
) -> None:
    dispatch_focus(client, dry_run=dry_run)
    monitor_target = monitor_dispatch_target(monitors, monitor_key(monitor))
    dispatch_lua(
        f"hl.dsp.window.move({{ monitor = {lua_scalar(monitor_target)}, window = {lua_string(window_selector(client))} }})",
        dry_run=dry_run,
    )


def apply_relative_geometry_on_monitor(
    client: dict[str, Any],
    source_monitor: dict[str, Any],
    target_monitor: dict[str, Any],
    *,
    dry_run: bool = False,
) -> None:
    at = client.get("at")
    size = client.get("size")
    if not isinstance(at, list) or not isinstance(size, list) or len(at) < 2 or len(size) < 2:
        raise SystemExit("active window has no geometry to preserve")

    source_w, source_h = monitor_logical_size(source_monitor)
    target_w, target_h = monitor_logical_size(target_monitor)
    source_x = int(source_monitor.get("x", 0))
    source_y = int(source_monitor.get("y", 0))

    left_ratio = max(0.0, min(1.0, (int(at[0]) - source_x) / source_w))
    top_ratio = max(0.0, min(1.0, (int(at[1]) - source_y) / source_h))
    width_ratio = max(0.05, min(1.0, int(size[0]) / source_w))
    height_ratio = max(0.05, min(1.0, int(size[1]) / source_h))

    local_x = min(round(target_w * left_ratio), target_w - 1)
    local_y = min(round(target_h * top_ratio), target_h - 1)
    width = min(round(target_w * width_ratio), target_w - local_x)
    height = min(round(target_h * height_ratio), target_h - local_y)
    apply_geometry_on_monitor(
        client,
        target_monitor,
        local_x,
        local_y,
        max(1, width),
        max(1, height),
        dry_run=dry_run,
    )

def summon_app(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    apps = load_apps(config_dir)
    if args.app not in apps:
        raise SystemExit(f"unknown app {args.app!r}")

    app_config = apps[args.app]
    state = load_state()
    clients = hyprctl_json("clients")
    active = hyprctl_json("activewindow")
    if not isinstance(clients, list):
        clients = []
    if not isinstance(active, dict):
        active = {}

    should_place_existing = app_places_client(app_config, args)
    should_place_launch = app_places_launched_client(app_config, args)
    current_app = app_for_client(apps, active)
    current_address = address(active)
    previous = client_by_address(clients, state.get("previous_address"))


    if current_app == args.app and previous and not should_place_existing:
        dispatch_focus(previous, dry_run=args.dry_run)
        state["last_by_app"][current_app] = address(active)
        if not args.dry_run:
            save_state(state)
        return 0

    if current_address and current_app != args.app:
        state["previous_address"] = current_address

    target = best_client(clients, args.app, app_config, active, state)
    if target:
        dispatch_focus(target, dry_run=args.dry_run)
        state["last_by_app"][args.app] = address(target)
        if should_place_existing:
            place_app_client(
                args.app,
                app_config,
                target,
                config_dir,
                dry_run=args.dry_run,
                force=args.force,
                require_place=should_place_existing,
            )
        if not args.dry_run:
            save_state(state)
        return 0

    known_addresses = {known_address for known_address in (address(client) for client in clients) if known_address}
    workspace = app_config.get("workspace")
    if workspace:
        dispatch_lua(f"hl.dsp.focus({{ workspace = {lua_scalar(workspace)} }})", dry_run=args.dry_run)
    launch(str(app_config["exec"]), dry_run=args.dry_run)

    if should_place_launch and not args.dry_run:
        target = wait_for_matching_client(
            app_config,
            known_addresses,
            timeout=max(float(args.launch_timeout), 0.0),
        )
        if target:
            state["last_by_app"][args.app] = address(target)
            place_app_client(
                args.app,
                app_config,
                target,
                config_dir,
                force=args.force,
                require_place=should_place_existing,
            )

    if not args.dry_run:
        save_state(state)
    return 0

def active_window() -> dict[str, Any]:
    active = hyprctl_json("activewindow")
    if not isinstance(active, dict) or not address(active):
        raise SystemExit("no active window")
    return active


def active_monitors() -> list[dict[str, Any]]:
    monitors = hyprctl_json("monitors")
    if not isinstance(monitors, list):
        return []
    return monitors


def move_to_region(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    regions = load_regions(config_dir)
    region = regions.get(args.region)
    if not region:
        raise SystemExit(f"unknown region {args.region!r}")

    active = active_window()
    if active.get("fullscreen") and not args.force:
        raise SystemExit("refusing to move fullscreen window without --force")

    apply_region(region, active, active_monitors(), dry_run=args.dry_run)
    return 0


def cycle_region(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    regions = load_regions(config_dir)
    names = list(args.regions) if args.regions else list(regions)
    if not names:
        raise SystemExit("no regions configured")
    missing = [name for name in names if name not in regions]
    if missing:
        raise SystemExit("unknown region(s): " + ", ".join(missing))

    active = active_window()
    if active.get("fullscreen") and not args.force:
        raise SystemExit("refusing to move fullscreen window without --force")

    target = address(active)
    state = load_state()
    last_by_address = state.setdefault("last_region_by_address", {})
    previous = last_by_address.get(target)
    if previous in names:
        region_name = names[(names.index(previous) + 1) % len(names)]
    else:
        region_name = names[0]

    apply_region(regions[region_name], active, active_monitors(), dry_run=args.dry_run)
    if not args.dry_run:
        last_by_address[target] = region_name
        save_state(state)
    return 0



def move_to_cell(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    apps = load_apps(config_dir)
    regions = load_regions(config_dir)
    layouts = load_layouts(config_dir)
    state = load_state()
    active = active_window()
    if active.get("fullscreen") and not args.force:
        raise SystemExit("refusing to move fullscreen window without --force")

    monitor = monitor_for_window(active_monitors(), active)
    apply_cell_on_monitor(
        active,
        monitor,
        int(args.cell),
        apps,
        regions,
        layouts,
        state,
        persist_override=True,
        dry_run=args.dry_run,
    )
    if not args.dry_run:
        save_state(state)
    return 0


def switch_layout(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    apps = load_apps(config_dir)
    regions = load_regions(config_dir)
    layouts = load_layouts(config_dir)
    state = load_state()
    monitors = active_monitors()
    monitor = monitor_for_window(monitors, active_window() if getattr(args, "active_window", False) else None)

    names = layout_names(layouts)
    current_name, _ = layout_for_monitor(layouts, state, monitor)
    if args.layout_action == "cycle":
        layout_name = names[(names.index(current_name) + 1) % len(names)]
        set_layout_for_monitor(state, monitor, layout_name)
        reapply_layout_on_monitor(
            monitor,
            apps,
            regions,
            layouts,
            state,
            dry_run=args.dry_run,
            force=args.force,
        )
    elif args.layout_action == "apply":
        if args.name not in layouts:
            raise SystemExit(f"unknown layout {args.name!r}")
        set_layout_for_monitor(state, monitor, args.name)
        reapply_layout_on_monitor(
            monitor,
            apps,
            regions,
            layouts,
            state,
            dry_run=args.dry_run,
            force=args.force,
        )
    elif args.layout_action == "reset":
        state.setdefault("layout_by_monitor", {}).pop(monitor_key(monitor), None)
        prefix = f"{monitor_key(monitor)}:{current_name}:"
        overrides = state.setdefault("app_cell_overrides", {})
        for key in list(overrides):
            if key.startswith(prefix):
                overrides.pop(key, None)
        reapply_layout_on_monitor(
            monitor,
            apps,
            regions,
            layouts,
            state,
            dry_run=args.dry_run,
            force=args.force,
        )
    else:
        raise SystemExit(f"unknown layout action {args.layout_action!r}")

    if not args.dry_run:
        save_state(state)
    return 0


def move_to_other_monitor(args: argparse.Namespace) -> int:
    config_dir = Path(args.config_dir)
    apps = load_apps(config_dir)
    regions = load_regions(config_dir)
    layouts = load_layouts(config_dir)
    state = load_state()
    active = active_window()
    if active.get("fullscreen") and not args.force:
        raise SystemExit("refusing to move fullscreen window without --force")

    monitors = active_monitors()
    source_monitor = monitor_for_window(monitors, active)
    direction = -1 if args.direction == "previous" else 1
    target_monitor = other_monitor_for_client(monitors, active, direction=direction)
    move_window_to_monitor(active, target_monitor, monitors, dry_run=args.dry_run)

    app_name = app_for_client(apps, active)
    layout_name, layout = layout_for_monitor(layouts, state, target_monitor)
    cell_index = configured_app_cell(app_name, layout_name, layout, state, target_monitor)
    if cell_index is not None:
        apply_cell_on_monitor(
            active,
            target_monitor,
            cell_index,
            apps,
            regions,
            layouts,
            state,
            dry_run=args.dry_run,
        )
    elif app_name and apps[app_name].get("region"):
        region_name = str(apps[app_name]["region"])
        region = regions.get(region_name)
        if not region:
            raise SystemExit(f"unknown region {region_name!r} for app {app_name!r}")
        apply_region_on_monitor(region, active, target_monitor, dry_run=args.dry_run)
    else:
        apply_relative_geometry_on_monitor(
            active,
            source_monitor,
            target_monitor,
            dry_run=args.dry_run,
        )

    dispatch_focus(active, dry_run=args.dry_run)
    if not args.dry_run:
        save_state(state)
    return 0

def inspect_active(args: argparse.Namespace) -> int:
    apps = load_apps(Path(args.config_dir))
    active = hyprctl_json("activewindow")
    name = app_for_client(apps, active if isinstance(active, dict) else {})
    print(name or "")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Hyprland app summon and region placement")
    parser.add_argument("--config-dir", default=str(default_config_dir()))
    parser.add_argument("--dry-run", action="store_true")
    subparsers = parser.add_subparsers(dest="command", required=True)

    app_parser = subparsers.add_parser("app", help="focus or launch a registered app")
    app_parser.add_argument("app")
    placement_group = app_parser.add_mutually_exclusive_group()
    placement_group.add_argument("--place", action="store_true", help="force applying the app's default region")
    placement_group.add_argument("--no-place", action="store_true", help="focus or launch without applying the app's default region")
    app_parser.add_argument("--force", action="store_true", help="allow applying regions to fullscreen windows")
    app_parser.add_argument("--launch-timeout", type=float, default=8.0, help="seconds to wait for a launched app window")
    app_parser.set_defaults(func=summon_app)

    region_parser = subparsers.add_parser("region", help="move active window to a named region")
    region_parser.add_argument("region")
    region_parser.add_argument("--force", action="store_true", help="allow moving fullscreen windows")
    region_parser.set_defaults(func=move_to_region)

    cycle_parser = subparsers.add_parser("cycle", help="cycle active window through named regions")
    cycle_parser.add_argument("regions", nargs="*", help="region order; defaults to regions.toml order")
    cycle_parser.add_argument("--force", action="store_true", help="allow moving fullscreen windows")
    cycle_parser.set_defaults(func=cycle_region)

    cell_parser = subparsers.add_parser("cell", help="move active window to a cell in the active monitor layout")
    cell_parser.add_argument("cell", type=int)
    cell_parser.add_argument("--force", action="store_true", help="allow moving fullscreen windows")
    cell_parser.set_defaults(func=move_to_cell)

    layout_parser = subparsers.add_parser("layout", help="change or reapply the active monitor layout")
    layout_parser.add_argument("layout_action", choices=("apply", "cycle", "reset"))
    layout_parser.add_argument("name", nargs="?")
    layout_parser.add_argument("--force", action="store_true", help="allow moving fullscreen windows while reapplying")
    layout_parser.set_defaults(func=switch_layout)

    monitor_parser = subparsers.add_parser("monitor", help="move active window to another monitor")
    monitor_parser.add_argument("direction", choices=("next", "previous"), nargs="?", default="next")
    monitor_parser.add_argument("--force", action="store_true", help="allow moving fullscreen windows")
    monitor_parser.set_defaults(func=move_to_other_monitor)

    inspect_parser = subparsers.add_parser("inspect", help="print registered app matching the active window")
    inspect_parser.set_defaults(func=inspect_active)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except (HyprCtlError, OSError, ValueError) as exc:
        print(f"hypr-summon: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
