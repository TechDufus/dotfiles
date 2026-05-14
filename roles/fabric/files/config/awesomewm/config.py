#!/usr/bin/env python3
from __future__ import annotations

import calendar
import copy
import json
import re
import subprocess
import sys
import time
from datetime import date, datetime, timezone
from pathlib import Path

from fabric import Application, Fabricator
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.centerbox import CenterBox
from fabric.widgets.datetime import DateTime
from fabric.widgets.eventbox import EventBox
from fabric.widgets.image import Image
from fabric.widgets.label import Label
from fabric.widgets.scale import Scale
from fabric.widgets.x11 import X11Window as Window
from fabric.utils import get_relative_path


HOME = Path.home()
AI_STATUS_PATH = HOME / ".cache" / "ai-usage-monitor" / "status.json"
AI_PROVIDER_PREF_PATH = HOME / ".cache" / "ai-usage-monitor" / "provider.txt"
CODEX_SESSION_DIR = HOME / ".codex" / "sessions"
CODEX_SESSION_FILE_LIMIT = 12
CODEX_SESSION_TAIL_BYTES = 512 * 1024
MAX_TASK_LABELS = 5
BAR_HEIGHT = 37
VOLUME_POLL_MS = 1000
AI_POLL_MS = 5000
AI_PROVIDER_SWITCH_REFRESH_DELAYS_MS = (350, 1250)
ROOT_LAUNCHER_SIGNAL = "techdufus::launcher_root"
SETTINGS_LAUNCHER_SIGNAL = "techdufus::launcher_settings"
LAUNCHER_SIGNAL = ROOT_LAUNCHER_SIGNAL
AI_USAGE_URLS = {
    "codex": "https://chatgpt.com/codex/settings/usage",
    "claude": "https://console.anthropic.com/settings/limits",
}
AI_PROVIDER_DEFS = {
    "claude": {
        "label": "Claude",
        "metrics": [
            ("five_hour", "Session (5h)"),
            ("seven_day", "Weekly (7d)"),
            ("seven_day_sonnet", "Sonnet (7d)"),
            ("seven_day_opus", "Opus (7d)"),
        ],
    },
    "codex": {
        "label": "Codex",
        "metrics": [
            ("session", "Session"),
            ("weekly", "Weekly"),
            ("five_hour", "Session (5h)"),
            ("seven_day", "Weekly (7d)"),
        ],
    },
}

AWESOME_CLIENTS_LUA = r'''
local out = {}
local focused = client.focus
for _, c in ipairs(client.get()) do
  table.insert(out, (c.name or "") .. "\t" .. (c.class or "") .. "\t" .. (c.minimized and "true" or "false") .. "\t" .. tostring(c.window or "") .. "\t" .. ((focused == c) and "true" or "false"))
end
return table.concat(out, "\n")
'''

APP_LABELS = {
    "1password": "1Password",
    "chromium": "Chromium",
    "chromium-browser": "Chromium",
    "code": "Code",
    "com.mitchellh.ghostty": "Ghostty",
    "discord": "Discord",
    "firefox": "Firefox",
    "ghostty": "Ghostty",
    "google-chrome": "Chrome",
    "slack": "Slack",
    "spotify": "Spotify",
    "steam": "Steam",
}

ICON_NAMES = {
    "1password": "1password",
    "brave-browser": "brave-browser",
    "chromium": "chromium",
    "chromium-browser": "chromium-browser",
    "code": "visual-studio-code",
    "com.mitchellh.ghostty": "com.mitchellh.ghostty",
    "discord": "discord",
    "firefox": "firefox",
    "ghostty": "com.mitchellh.ghostty",
    "google-chrome": "google-chrome",
    "slack": "slack",
    "spotify": "spotify",
    "steam": "steam",
}

Task = dict[str, object]


def bar_size_from_monitor_width(width: int) -> tuple[int, int]:
    return (width, BAR_HEIGHT)


def primary_monitor_width() -> int:
    try:
        from gi.repository import Gdk

        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor() if display else None
        geometry = monitor.get_geometry() if monitor else None
        return int(geometry.width) if geometry else 1920
    except Exception:
        return 1920


def run_command(command: list[str]) -> None:
    subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def awesome_signal_command(signal: str) -> list[str]:
    return ["awesome-client", f"awesome.emit_signal('{signal}')"]


def launcher_command() -> list[str]:
    return awesome_signal_command(LAUNCHER_SIGNAL)


def settings_command() -> list[str]:
    return awesome_signal_command(SETTINGS_LAUNCHER_SIGNAL)


def open_launcher() -> None:
    run_command(launcher_command())


def open_settings_launcher() -> None:
    run_command(settings_command())


def shell_output(command: str, fallback: str = "...") -> str:
    try:
        result = subprocess.run(
            ["sh", "-c", command],
            check=False,
            capture_output=True,
            text=True,
            timeout=1,
        )
    except Exception:
        return fallback

    value = result.stdout.strip()
    return value or fallback


def command_output(command: list[str], fallback: str = "") -> str:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=1,
        )
    except Exception:
        return fallback

    return result.stdout.strip() or fallback


def nested_value(data: object, *keys: str) -> object:
    current = data
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def as_number(value: object) -> float | None:
    try:
        return float(value)
    except Exception:
        return None


def percent_text(value: object) -> str | None:
    try:
        return f"{int(float(value))}%"
    except Exception:
        return None


def percent_display(value: object) -> str:
    number = as_number(value)
    if number is None:
        return "N/A"
    return f"{int(number + 0.5)}%"


def progress_value(value: object) -> float:
    number = as_number(value)
    if number is None:
        return 0.0
    return max(0.0, min(1.0, number / 100.0))


def usage_severity(value: object) -> str:
    number = as_number(value)
    if number is None:
        return "unknown"
    if number < 50:
        return "cool"
    if number <= 70:
        return "warm"
    if number <= 85:
        return "hot"
    return "critical"


def usage_status(value: object) -> str:
    return {
        "unknown": "Unknown",
        "cool": "Healthy",
        "warm": "Warm",
        "hot": "Hot",
        "critical": "Critical",
    }[usage_severity(value)]


def normalize_ai_provider(provider: str, fallback: str = "codex") -> str:
    value = provider.strip().lower()
    if value in AI_PROVIDER_DEFS:
        return value
    return fallback if fallback in AI_PROVIDER_DEFS else "codex"


def load_ai_provider_preference(path: Path | None = None) -> str:
    path = AI_PROVIDER_PREF_PATH if path is None else path
    try:
        return normalize_ai_provider(path.read_text().strip())
    except Exception:
        return "codex"


def save_ai_provider_preference(provider: str, path: Path | None = None) -> None:
    path = AI_PROVIDER_PREF_PATH if path is None else path
    value = normalize_ai_provider(provider)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{value}\n")
    except Exception:
        return


def next_ai_provider(provider: str) -> str:
    return "claude" if normalize_ai_provider(provider) == "codex" else "codex"


def iso_to_epoch(iso: object) -> float | None:
    if not isinstance(iso, str) or not iso:
        return None
    try:
        return datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()
    except Exception:
        return None


def duration_text(seconds: float) -> str:
    remaining = max(0, int(seconds))
    days, remaining = divmod(remaining, 86400)
    hours, remaining = divmod(remaining, 3600)
    minutes = remaining // 60
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    parts.append(f"{minutes:02d}m" if hours or days else f"{minutes}m")
    return " ".join(parts)


def local_time_text(epoch: float) -> str:
    return datetime.fromtimestamp(epoch).strftime("%-I:%M %p")


def format_reset_text(iso: object, now_epoch: float | None = None) -> str:
    reset_epoch = iso_to_epoch(iso)
    if reset_epoch is None:
        return "reset unknown"
    now = time.time() if now_epoch is None else now_epoch
    remaining = reset_epoch - now
    if remaining <= 0:
        return f"resets now ({local_time_text(reset_epoch)})"
    return f"resets in {duration_text(remaining)} ({local_time_text(reset_epoch)})"


def metric_percent_value(metric: object) -> object:
    if not isinstance(metric, dict):
        return None
    for key in ("used_percent", "utilization", "percentage", "percent", "usage"):
        value = metric.get(key)
        if value is not None:
            return value
    return None


def network_label_from_interface(interface: str) -> str:
    value = interface.strip().lower()
    if not value:
        return "OFF"
    if value.startswith(("tailscale", "tun", "tap", "wg", "zt")) or "vpn" in value:
        return "VPN"
    if value.startswith(("wl", "wifi", "wlan")):
        return "WIFI"
    if value.startswith(("en", "eth")):
        return "LAN"
    return "NET"


def volume_text() -> str:
    return shell_output(
        "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F'/' 'NR==1 {gsub(/ /,\"\",$2); print $2}'",
        "vol",
    )


def toggle_volume() -> None:
    run_command(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])


def change_volume(delta: int) -> None:
    sign = "+" if delta > 0 else "-"
    run_command(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{sign}{abs(delta)}%"])


def open_audio_mixer() -> None:
    run_command(
        [
            "sh",
            "-c",
            "command -v pavucontrol >/dev/null && exec pavucontrol; command -v pwvucontrol >/dev/null && exec pwvucontrol; exec x-terminal-emulator -e alsamixer",
        ]
    )


def audio_devices_listing() -> str:
    return command_output(
        [
            "sh",
            "-c",
            "printf 'default_sink\\t%s\\n' \"$(pactl get-default-sink 2>/dev/null)\"; "
            "pactl list short sinks 2>/dev/null | awk '{print \"sink\\t\" $2}'; "
            "printf 'default_source\\t%s\\n' \"$(pactl get-default-source 2>/dev/null)\"; "
            "pactl list short sources 2>/dev/null | awk '{print \"source\\t\" $2}'",
        ],
        "",
    )


def parse_audio_devices(stdout: str) -> dict[str, object]:
    parsed: dict[str, object] = {
        "default_sink": "",
        "default_source": "",
        "sinks": [],
        "sources": [],
    }
    for line in stdout.splitlines():
        kind, _, value = line.partition("\t")
        if kind == "default_sink":
            parsed["default_sink"] = value
        elif kind == "default_source":
            parsed["default_source"] = value
        elif kind == "sink" and value:
            parsed["sinks"].append(value)
        elif kind == "source" and value:
            parsed["sources"].append(value)
    return parsed


def set_default_audio_device(kind: str, name: str) -> None:
    if kind == "sink":
        run_command(["pactl", "set-default-sink", name])
    elif kind == "source":
        run_command(["pactl", "set-default-source", name])


def short_audio_name(name: str) -> str:
    value = name.strip()
    for prefix in ("alsa_output.", "alsa_input.", "bluez_output.", "bluez_input."):
        if value.startswith(prefix):
            value = value[len(prefix):]
    return value.replace("_", " ")[:38] if value else "unknown"


def calendar_text_from_output(text: str) -> str:
    value = text.rstrip()
    return value or "calendar unavailable"


def shifted_month(year: int, month: int, delta: int) -> tuple[int, int]:
    index = (year * 12) + (month - 1) + delta
    return index // 12, (index % 12) + 1


def calendar_text_for_months(year: int, month: int) -> str:
    renderer = calendar.TextCalendar(calendar.SUNDAY)
    rendered = []
    for delta in (-1, 0, 1):
        item_year, item_month = shifted_month(year, month, delta)
        rendered.append(renderer.formatmonth(item_year, item_month).rstrip())
    return "\n\n".join(rendered)


def calendar_text() -> str:
    today = date.today()
    return calendar_text_for_months(today.year, today.month)


def battery_value_from_output(text: str) -> str | None:
    value = text.strip()
    return value or None


def battery_value() -> str | None:
    return battery_value_from_output(
        shell_output(
            'battery="$(upower -e 2>/dev/null | grep BAT | head -n1)"; '
            'if [ -n "$battery" ]; then upower -i "$battery" | awk \'/percentage:/ {print $2; exit}\'; fi',
            "",
        )
    )


def dnd_lua(command: str) -> str:
    return f"local dnd = require('notifications').dnd; {command}"


def normalize_dnd_text(text: str) -> str:
    value = text.strip().lower()
    if "true" in value or '"on"' in value or value == "on":
        return "on"
    return "off"


def dnd_text() -> str:
    return normalize_dnd_text(
        command_output(
            ["awesome-client", dnd_lua("return dnd.is_enabled() and 'on' or 'off'")],
            "off",
        )
    )


def toggle_dnd() -> str:
    return normalize_dnd_text(
        command_output(
            ["awesome-client", dnd_lua("return dnd.toggle() and 'on' or 'off'")],
            "off",
        )
    )


def focus_window(window_id: str) -> None:
    if not window_id.isdigit():
        return

    run_command(
        [
            "awesome-client",
            (
                "local target = tonumber('%s'); "
                "for _, c in ipairs(client.get()) do "
                "if c.window == target then "
                "c.minimized = false; "
                "c:emit_signal('request::activate', 'fabric-taskbar', {raise = true}); "
                "return true "
                "end "
                "end "
                "return false"
            )
            % window_id,
        ]
    )


def open_client_menu() -> None:
    run_command(
        [
            "awesome-client",
            'local awful = require("awful"); awful.menu.client_list({ theme = { width = 250 } })',
        ]
    )


def battery_text() -> str:
    return battery_value() or ""


def network_text() -> str:
    interface = shell_output(
        "ip -o -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i==\"dev\") {print $(i+1); exit}}'",
        "",
    )
    return network_label_from_interface(interface)


def decode_awesome_string(stdout: str) -> str:
    value = stdout.strip()
    prefix = 'string "'
    if value.startswith(prefix):
        value = value[len(prefix):]
        if value.endswith('"'):
            value = value[:-1]
    return value.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"')


def app_label(title: str, class_name: str) -> str:
    mapped = APP_LABELS.get(class_name.strip().lower())
    if mapped:
        return mapped

    candidate = title.strip() or class_name.strip() or "App"
    for separator in (" - ", " | ", " :: "):
        if separator in candidate:
            candidate = candidate.rsplit(separator, 1)[-1]
            break

    candidate = re.sub(r"\s+", " ", candidate).strip()
    return candidate[:22] if len(candidate) > 22 else candidate


def initials_for_label(label: str) -> str:
    clean = re.sub(r"[^A-Za-z0-9]+", " ", label).strip()
    if not clean:
        return "?"
    if clean[0].isdigit():
        return clean[0]
    parts = clean.split()
    if len(parts) >= 2:
        return (parts[0][0] + parts[1][0]).upper()
    return clean[0].upper()


def icon_name_for_class(class_name: str) -> str:
    key = class_name.strip().lower()
    return ICON_NAMES.get(key) or key or "application-x-executable"


def icon_theme_has_icon(icon_name: str) -> bool:
    try:
        from gi.repository import Gtk

        theme = Gtk.IconTheme.get_default()
        return bool(theme and theme.has_icon(icon_name))
    except Exception:
        return False


def is_fabric_client(title: str, class_name: str) -> bool:
    title_key = title.strip().lower()
    class_key = class_name.strip().lower()
    if class_key in {"config.py", "fabric", "fabric-awesomewm"}:
        return True
    if title_key == "fabric" or "fabric-awesomewm" in title_key:
        return True
    return "config.py" in title_key and "fabric" in title_key


def parse_awesome_clients(stdout: str) -> list[Task]:
    tasks = []
    for line in decode_awesome_string(stdout).splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        title = parts[0] if len(parts) > 0 else ""
        class_name = parts[1] if len(parts) > 1 else ""
        minimized = (parts[2] if len(parts) > 2 else "false").strip().lower() == "true"
        window_id = (parts[3] if len(parts) > 3 else "").strip()
        focused = (parts[4] if len(parts) > 4 else "false").strip().lower() == "true"
        if is_fabric_client(title, class_name):
            continue
        tasks.append(
            {
                "label": app_label(title, class_name),
                "class_name": class_name,
                "minimized": minimized,
                "window_id": window_id,
                "focused": focused,
            }
        )
    return tasks


def group_tasks_for_dock(tasks: list[Task], max_icons: int = MAX_TASK_LABELS) -> list[Task]:
    grouped_by_class: dict[str, Task] = {}
    ordered: list[Task] = []

    for task in tasks:
        class_name = str(task.get("class_name") or "")
        label = str(task.get("label") or "App")
        key = class_name.strip().lower() or label.lower()
        existing = grouped_by_class.get(key)
        window_id = str(task.get("window_id") or "")
        if existing is None:
            grouped = {
                "label": label,
                "class_name": class_name,
                "window_ids": [window_id],
                "count": 1,
                "focused": bool(task.get("focused")),
            }
            grouped_by_class[key] = grouped
            ordered.append(grouped)
        else:
            existing["window_ids"].append(window_id)
            existing["count"] = int(existing["count"]) + 1
            existing["focused"] = bool(existing.get("focused")) or bool(task.get("focused"))

    return ordered[:max_icons]


def overflow_count_for_tasks(tasks: list[Task], max_icons: int = MAX_TASK_LABELS) -> int:
    unique_count = len(group_tasks_for_dock(tasks, max_icons=1000))
    return max(0, unique_count - max_icons)


def task_button_labels(tasks: list[Task]) -> list[str]:
    counts = {}
    labels = []
    for task in tasks[:MAX_TASK_LABELS]:
        label = str(task.get("label") or "App")
        counts[label] = counts.get(label, 0) + 1
        labels.append(label if counts[label] == 1 else f"{label} {counts[label]}")
    return labels


def tasks_text(tasks: list[Task]) -> str:
    if not tasks:
        return "none"

    rendered = task_button_labels(tasks)
    hidden_count = max(0, len(tasks) - MAX_TASK_LABELS)
    if hidden_count:
        rendered.append(f"+{hidden_count}")
    return "  ".join(rendered)


def running_tasks() -> list[Task]:
    stdout = command_output(["awesome-client", AWESOME_CLIENTS_LUA])
    return parse_awesome_clients(stdout)


def running_apps_text() -> str:
    return tasks_text(running_tasks())


def ai_usage_from_status(data: object) -> str:
    codex_session = nested_value(data, "codex", "session", "utilization")
    claude_five_hour = nested_value(data, "claude", "five_hour", "utilization")
    value = codex_session if codex_session is not None else claude_five_hour
    if value is None:
        return "AI"

    return percent_text(value) or "AI"


def ai_summary_from_status(data: object) -> dict[str, object]:
    status = data if isinstance(data, dict) else {}
    codex = status.get("codex", {}) if isinstance(status.get("codex"), dict) else {}
    claude = status.get("claude", {}) if isinstance(status.get("claude"), dict) else {}
    errors = status.get("errors", [])
    normalized_errors = errors if isinstance(errors, list) else []

    if codex.get("available"):
        return {
            "provider": "codex",
            "session": percent_text(nested_value(codex, "session", "utilization")) or "AI",
            "weekly": percent_text(nested_value(codex, "weekly", "utilization")) or "AI",
            "session_resets_at": nested_value(codex, "session", "resets_at") or "",
            "weekly_resets_at": nested_value(codex, "weekly", "resets_at") or "",
            "timestamp": status.get("timestamp", ""),
            "errors": normalized_errors,
        }

    return {
        "provider": "claude",
        "session": percent_text(nested_value(claude, "five_hour", "utilization")) or "AI",
        "weekly": percent_text(nested_value(claude, "seven_day", "utilization")) or "AI",
        "session_resets_at": nested_value(claude, "five_hour", "resets_at") or "",
        "weekly_resets_at": nested_value(claude, "seven_day", "resets_at") or "",
        "timestamp": status.get("timestamp", ""),
        "errors": normalized_errors,
    }


def metric_from_provider(provider: object, metric_key: str) -> dict[str, object] | None:
    if not isinstance(provider, dict):
        return None

    metric = provider.get(metric_key)
    if isinstance(metric, dict):
        return metric

    value = None
    for key in (f"{metric_key}_utilization", f"{metric_key}_percentage", f"{metric_key}_percent", f"{metric_key}_usage"):
        if provider.get(key) is not None:
            value = provider.get(key)
            break
    if value is None:
        return None

    reset = None
    for key in (f"{metric_key}_resets_at", f"{metric_key}_reset_at", f"{metric_key}_resets_on", f"{metric_key}_reset_on"):
        if provider.get(key) is not None:
            reset = provider.get(key)
            break

    return {
        "utilization": value,
        "resets_at": reset,
    }


def metric_percent(metric: object) -> float | None:
    if not isinstance(metric, dict):
        return None
    for key in ("utilization", "percentage", "percent", "usage"):
        value = as_number(metric.get(key))
        if value is not None:
            return value
    return None


def metric_reset(metric: object) -> object:
    if not isinstance(metric, dict):
        return None
    return metric.get("resets_at") or metric.get("reset_at") or metric.get("resets_on") or metric.get("reset_on") or metric.get("window_end")


def ai_provider_tabs(data: object, active_provider: str) -> list[dict[str, object]]:
    status = data if isinstance(data, dict) else {}
    tabs = []
    for provider_key in ("claude", "codex"):
        provider = status.get(provider_key)
        provider_data = provider if isinstance(provider, dict) else {}
        tabs.append(
            {
                "provider": provider_key,
                "label": str(AI_PROVIDER_DEFS[provider_key]["label"]),
                "active": provider_key == active_provider,
                "available": bool(provider_data.get("available")),
                "error": str(provider_data.get("error") or ""),
            }
        )
    return tabs


def ai_metric_rows(data: object, provider_key: str, now_epoch: float | None = None) -> list[dict[str, object]]:
    status = data if isinstance(data, dict) else {}
    provider = status.get(provider_key)
    provider_data = provider if isinstance(provider, dict) else {}
    rows = []
    seen_keys = set()
    provider_def = AI_PROVIDER_DEFS[provider_key]
    for metric_key, metric_label in provider_def["metrics"]:
        if metric_key in seen_keys:
            continue
        metric = metric_from_provider(provider_data, metric_key)
        if metric is None:
            continue
        percent = metric_percent(metric)
        rows.append(
            {
                "key": metric_key,
                "label": metric_label,
                "percent": percent,
                "percent_text": percent_display(percent),
                "progress": progress_value(percent),
                "severity": usage_severity(percent),
                "status": usage_status(percent),
                "reset_text": format_reset_text(metric_reset(metric), now_epoch=now_epoch),
            }
        )
        seen_keys.add(metric_key)
    return rows


def claude_credit_row(data: object) -> dict[str, object] | None:
    if not isinstance(data, dict):
        return None
    extra = nested_value(data, "claude", "extra_usage")
    if not isinstance(extra, dict) or not extra.get("is_enabled"):
        return None
    percent = as_number(extra.get("utilization"))
    used = extra.get("used_credits", 0)
    limit = extra.get("monthly_limit", 0)
    return {
        "key": "credits",
        "label": "Credits",
        "percent": percent,
        "percent_text": percent_display(percent),
        "progress": progress_value(percent),
        "severity": usage_severity(percent),
        "status": usage_status(percent),
        "reset_text": f"{used} / {limit}",
    }


def ai_dashboard_model(data: object, provider: str, now_epoch: float | None = None) -> dict[str, object]:
    active_provider = normalize_ai_provider(provider)
    provider_label = str(AI_PROVIDER_DEFS[active_provider]["label"])
    status = data if isinstance(data, dict) else {}
    provider_data = status.get(active_provider)
    provider_data = provider_data if isinstance(provider_data, dict) else {}
    provider_pending = ai_provider_status_pending(status, active_provider)

    rows = ai_metric_rows(status, active_provider, now_epoch=now_epoch)
    if active_provider == "claude":
        credits = claude_credit_row(status)
        if credits is not None:
            rows.append(credits)

    status_messages = []
    provider_error = provider_data.get("error")
    if not rows and provider_pending:
        status_messages.append(f"Refreshing {provider_label} usage...")
    elif not rows and provider_data.get("available") is False:
        status_messages.append(f"{provider_label} unavailable: {provider_error or 'no usage data'}")
    elif not rows:
        status_messages.append(f"{provider_label} usage unavailable")

    primary_percent = rows[0]["percent"] if rows else None
    return {
        "active_provider": active_provider,
        "title": f"{provider_label} Usage",
        "tabs": ai_provider_tabs(status, active_provider),
        "rows": rows,
        "status_messages": status_messages,
        "primary_percent": primary_percent,
        "primary_percent_text": percent_display(primary_percent),
        "primary_severity": usage_severity(primary_percent),
        "primary_status": usage_status(primary_percent),
    }


def ai_compact_usage_from_status(data: object, provider: str, live_codex: str | None = None) -> str:
    active_provider = normalize_ai_provider(provider)
    if active_provider == "codex" and live_codex is not None:
        return live_codex

    rows = ai_metric_rows(data, active_provider)
    if not rows:
        if ai_provider_status_pending(data, active_provider):
            return "..."
        return "--"
    return percent_display(rows[0].get("percent"))


def ai_provider_status_pending(data: object, active_provider: str) -> bool:
    active_provider = normalize_ai_provider(active_provider)
    status = data if isinstance(data, dict) else {}
    status_provider = status.get("active_provider")
    if isinstance(status_provider, str) and status_provider in AI_PROVIDER_DEFS and status_provider != active_provider:
        return True

    provider_data = status.get(active_provider)
    if isinstance(provider_data, dict) and provider_data.get("error") == "monitor_stopped":
        return True

    return False


def percent_number_from_text(text: str | None) -> float | None:
    if not text:
        return None
    match = re.search(r"(\d+(?:\.\d+)?)\s*%", text)
    return as_number(match.group(1)) if match else None


def status_with_live_codex_usage(data: object, live_codex: str | None) -> object:
    percent = percent_number_from_text(live_codex)
    if percent is None or not isinstance(data, dict):
        return data
    updated = copy.deepcopy(data)
    codex = updated.setdefault("codex", {})
    if not isinstance(codex, dict):
        return data
    session = codex.setdefault("session", {})
    if isinstance(session, dict):
        session["utilization"] = percent
    codex["available"] = True
    return updated


def ai_status_data() -> object:
    try:
        return json.loads(AI_STATUS_PATH.read_text())
    except Exception:
        return {}


def current_ai_summary() -> dict[str, object]:
    summary = ai_summary_from_status(ai_status_data())
    provider = load_ai_provider_preference()
    live_codex = codex_live_usage_text() if provider == "codex" else None
    if provider == "codex" and live_codex is not None:
        summary["provider"] = "codex"
        summary["session"] = live_codex
    return summary


def restart_ai_usage_monitor() -> None:
    run_command(["systemctl", "--user", "restart", "ai-usage-monitor.service"])


def schedule_ai_provider_refreshes(callback, scheduler=None, delays: tuple[int, ...] = AI_PROVIDER_SWITCH_REFRESH_DELAYS_MS) -> bool:
    if scheduler is None:
        try:
            from gi.repository import GLib

            scheduler = GLib.timeout_add
        except Exception:
            return False

    for delay in delays:
        def run_once(callback=callback):
            callback()
            return False

        scheduler(int(delay), run_once)

    return bool(delays)


def open_ai_usage_url(provider: str) -> None:
    url = AI_USAGE_URLS.get(provider) or AI_USAGE_URLS["codex"]
    run_command(["xdg-open", url])


def event_has_shift(event: object) -> bool:
    try:
        from gi.repository import Gdk

        return bool(int(getattr(event, "state", 0)) & int(Gdk.ModifierType.SHIFT_MASK))
    except Exception:
        return "shift" in str(getattr(event, "state", "")).lower()


def codex_usage_from_rate_limits(rate_limits: object) -> str | None:
    if isinstance(rate_limits, list):
        for item in reversed(rate_limits):
            usage = codex_usage_from_rate_limits(item)
            if usage is not None:
                return usage
        return None

    if not isinstance(rate_limits, dict):
        return None

    limit_id = rate_limits.get("limit_id")
    if limit_id not in (None, "codex"):
        return None

    for source in (rate_limits.get("primary"), rate_limits.get("session"), rate_limits):
        value = metric_percent_value(source)
        if value is not None:
            return percent_text(value)
    return None


def codex_usage_text_from_lines(lines: list[str]) -> str | None:
    for line in reversed(lines):
        if "token_count" not in line or "rate_limit" not in line:
            continue
        try:
            event = json.loads(line)
        except Exception:
            continue
        if not isinstance(event, dict) or event.get("type") != "event_msg":
            continue

        payload = event.get("payload")
        if not isinstance(payload, dict) or payload.get("type") != "token_count":
            continue

        info = payload.get("info") if isinstance(payload.get("info"), dict) else {}
        rate_limits = info.get("rate_limits") or payload.get("rate_limits")
        usage = codex_usage_from_rate_limits(rate_limits)
        if usage is not None:
            return usage
    return None


def recent_codex_session_files(session_dir: Path = CODEX_SESSION_DIR) -> list[Path]:
    try:
        files = [path for path in session_dir.rglob("*.jsonl") if path.is_file()]
    except Exception:
        return []

    def file_mtime(path: Path) -> float:
        try:
            return path.stat().st_mtime
        except Exception:
            return 0

    return sorted(files, key=file_mtime, reverse=True)[:CODEX_SESSION_FILE_LIMIT]


def tail_lines(path: Path, max_bytes: int = CODEX_SESSION_TAIL_BYTES) -> list[str]:
    try:
        with path.open("rb") as handle:
            handle.seek(0, 2)
            size = handle.tell()
            handle.seek(max(0, size - max_bytes))
            return handle.read().decode("utf-8", errors="replace").splitlines()
    except Exception:
        return []


def codex_live_usage_text() -> str | None:
    for path in recent_codex_session_files():
        usage = codex_usage_text_from_lines(tail_lines(path))
        if usage is not None:
            return usage
    return None


def ai_usage_text() -> str:
    provider = load_ai_provider_preference()
    live_codex = codex_live_usage_text() if provider == "codex" else None
    try:
        data = json.loads(AI_STATUS_PATH.read_text())
    except Exception:
        data = {}

    return ai_compact_usage_from_status(data, provider, live_codex=live_codex)


def run_self_check() -> int:
    for check in (volume_text, battery_value, network_text, ai_usage_text, running_apps_text, dnd_text):
        check()
    return 0


class StatusPill(Box):
    def __init__(self, label: str, initial: str = "...", **kwargs):
        self.label = Label(name="pill-label", label=label)
        self.value = Label(name="pill-value", label=initial)
        super().__init__(
            name="status-pill",
            orientation="h",
            spacing=5,
            children=[self.label, self.value],
            **kwargs,
        )

    def set_value(self, value: str) -> None:
        self.value.set_label(value)


class TaskStrip(Box):
    def __init__(self, **kwargs):
        self.task_buttons = Box(
            name="task-buttons",
            orientation="h",
            spacing=5,
            children=[Label(name="task-empty", label="idle")],
        )
        super().__init__(
            name="task-strip",
            orientation="h",
            spacing=0,
            children=[self.task_buttons],
            **kwargs,
        )

    def task_child(self, task: Task) -> Box | Label:
        label = str(task.get("label") or "App")
        class_name = str(task.get("class_name") or "")
        icon_name = icon_name_for_class(class_name)
        count = int(task.get("count") or 1)
        if icon_theme_has_icon(icon_name):
            app_child = Image(icon_name=icon_name, icon_size=16)
        else:
            app_child = Label(name="task-initials", label=initials_for_label(label))

        if count <= 1:
            return app_child

        return Box(
            name="task-button-inner",
            orientation="h",
            spacing=1,
            children=[
                app_child,
                Label(name="task-count-badge", label=str(count)),
            ],
        )

    def set_tasks(self, tasks: list[Task]) -> None:
        if not tasks:
            self.task_buttons.children = [Label(name="task-empty", label="idle")]
            return

        grouped_tasks = group_tasks_for_dock(tasks)
        children = []
        for task in grouped_tasks:
            window_ids = task.get("window_ids") if isinstance(task.get("window_ids"), list) else []
            window_id = str(window_ids[0]) if window_ids else ""
            label = str(task.get("label") or "App")
            class_name = str(task.get("class_name") or label)
            button = Button(
                name="task-button",
                style_classes=["focused"] if bool(task.get("focused")) else [],
                child=self.task_child(task),
                on_clicked=lambda *_args, target=window_id: focus_window(target),
            )
            button.set_tooltip_text(class_name)
            children.append(button)

        hidden_count = overflow_count_for_tasks(tasks)
        if hidden_count:
            children.append(
                Button(
                    name="task-overflow",
                    child=Label(label=f"+{hidden_count}"),
                    on_clicked=lambda *_: open_client_menu(),
                )
            )

        self.task_buttons.children = children


class PopupManager:
    def __init__(self, clock=time.monotonic, reopen_suppression_seconds: float = 0.18):
        self.clock = clock
        self.reopen_suppression_seconds = reopen_suppression_seconds
        self.popups: dict[str, object] = {}
        self.recent_focus_close: dict[str, float] = {}
        self.active_name: str | None = None

    def register(self, name: str, popup: object) -> None:
        self.popups[name] = popup

    def is_visible(self, name: str) -> bool:
        popup = self.popups.get(name)
        if popup is None:
            return False
        get_visible = getattr(popup, "get_visible", None)
        return bool(get_visible()) if callable(get_visible) else False

    def suppress_reopen(self, name: str) -> bool:
        closed_at = self.recent_focus_close.get(name)
        if closed_at is None:
            return False
        if self.clock() - closed_at <= self.reopen_suppression_seconds:
            self.recent_focus_close.pop(name, None)
            return True
        self.recent_focus_close.pop(name, None)
        return False

    def open(self, name: str) -> None:
        popup = self.popups.get(name)
        if popup is None:
            return
        self.close_all(except_name=name)
        refresh = getattr(popup, "refresh", None)
        if callable(refresh):
            refresh()
        show_all = getattr(popup, "show_all", None)
        if callable(show_all):
            show_all()
        present = getattr(popup, "present", None)
        if callable(present):
            present()
        self.active_name = name

    def close(self, name: str, reason: str = "manual") -> None:
        popup = self.popups.get(name)
        if popup is None:
            return
        hide = getattr(popup, "hide", None)
        if callable(hide):
            hide()
        if self.active_name == name:
            self.active_name = None
        if reason == "focus-out":
            self.recent_focus_close[name] = self.clock()

    def close_all(self, except_name: str | None = None) -> None:
        for name in list(self.popups):
            if name != except_name:
                self.close(name)

    def toggle(self, name: str) -> None:
        if self.is_visible(name) or self.active_name == name:
            self.close(name)
            return
        if self.suppress_reopen(name):
            return
        self.open(name)


class AudioDevicePopout(Window):
    def __init__(self):
        self.rows = Box(name="audio-popout-rows", orientation="v", spacing=4)
        super().__init__(
            name="audio-popout",
            layer="top",
            geometry="top-right",
            margin="37px 10px 0px 0px",
            type_hint="dialog",
            visible=False,
            child=Box(
                name="popout-panel",
                orientation="v",
                spacing=8,
                children=[
                    Label(name="popout-title", label="AUDIO"),
                    self.rows,
                ],
            ),
        )

    def refresh(self) -> None:
        devices = parse_audio_devices(audio_devices_listing())
        default_sink = str(devices.get("default_sink") or "")
        default_source = str(devices.get("default_source") or "")
        children = [
            Label(name="popout-section", label="OUTPUT"),
            *self.device_rows("sink", devices.get("sinks"), default_sink),
            Label(name="popout-section", label="INPUT"),
            *self.device_rows("source", devices.get("sources"), default_source),
        ]
        self.rows.children = children

    def device_rows(self, kind: str, devices: object, active: str) -> list[Button | Label]:
        if not isinstance(devices, list) or not devices:
            return [Label(name="popout-muted", label="none")]

        rows: list[Button | Label] = []
        for device in devices:
            name = str(device)
            marker = ">" if name == active else " "
            row = Button(
                name="audio-device-row",
                style_classes=["active"] if name == active else [],
                child=Label(label=f"{marker} {short_audio_name(name)}"),
                on_clicked=lambda *_args, target=name, target_kind=kind: set_default_audio_device(target_kind, target),
            )
            rows.append(row)
        return rows

    def toggle(self) -> None:
        if self.get_visible():
            self.hide()
            return
        self.refresh()
        self.show_all()


class AIUsagePopout(Window):
    def __init__(self, on_provider_changed=None):
        self.on_provider_changed = on_provider_changed
        self.panel = Box(name="ai-panel", orientation="v", spacing=9)
        super().__init__(
            name="ai-popout",
            layer="top",
            geometry="top-right",
            margin="37px 10px 0px 0px",
            type_hint="dialog",
            visible=False,
            child=self.panel,
        )

    def refresh(self) -> None:
        provider = load_ai_provider_preference()
        live_codex = codex_live_usage_text() if provider == "codex" else None
        status = status_with_live_codex_usage(ai_status_data(), live_codex)
        model = ai_dashboard_model(status, provider)
        children = [
            self.header(model),
            self.provider_tabs(model),
        ]
        if model["rows"]:
            children.extend(self.metric_row(row) for row in model["rows"])
        else:
            children.extend(self.status_message(message) for message in model["status_messages"])
        children.append(self.footer(model))
        self.panel.children = children

    def header(self, model: dict[str, object]) -> Box:
        return Box(
            name="ai-header",
            orientation="h",
            spacing=10,
            children=[
                Label(name="ai-title", label=str(model["title"])),
                Label(
                    name="ai-status-badge",
                    style_classes=[str(model["primary_severity"])],
                    label=str(model["primary_status"]),
                ),
                Label(name="ai-primary-percent", label=str(model["primary_percent_text"])),
            ],
        )

    def provider_tabs(self, model: dict[str, object]) -> Box:
        tabs = []
        for tab in model["tabs"]:
            provider = str(tab["provider"])
            style_classes = ["active"] if tab["active"] else []
            if not tab["available"]:
                style_classes.append("unavailable")
            button = Button(
                name="ai-provider-tab",
                style_classes=style_classes,
                child=Label(label=str(tab["label"])),
                on_clicked=lambda *_args, target=provider: self.select_provider(target),
            )
            tabs.append(button)

        return Box(name="ai-provider-tabs", orientation="h", spacing=6, children=tabs)

    def metric_row(self, row: dict[str, object]) -> Box:
        progress = Scale(
            name="ai-progress",
            style_classes=[str(row["severity"])],
            value=float(row["progress"]),
            min_value=0,
            max_value=1,
            draw_value=False,
            size=(238, 8),
        )
        progress.set_sensitive(False)
        return Box(
            name="ai-metric-row",
            orientation="v",
            spacing=4,
            children=[
                Box(
                    name="ai-metric-head",
                    orientation="h",
                    spacing=8,
                    children=[
                        Label(name="ai-metric-label", h_expand=True, label=str(row["label"])),
                        Label(name="ai-metric-value", style_classes=[str(row["severity"])], label=str(row["percent_text"])),
                    ],
                ),
                progress,
                Box(
                    name="ai-metric-foot",
                    orientation="h",
                    spacing=8,
                    children=[
                        Label(name="ai-metric-reset", h_expand=True, label=str(row["reset_text"])),
                        Label(name="ai-metric-status", style_classes=[str(row["severity"])], label=str(row["status"])),
                    ],
                ),
            ],
        )

    def status_message(self, message: str) -> Box:
        return Box(name="ai-status-message", children=[Label(label=message)])

    def footer(self, model: dict[str, object]) -> Box:
        provider = str(model["active_provider"])
        return Box(
            name="ai-footer",
            orientation="h",
            spacing=6,
            children=[
                Button(
                    name="ai-footer-button",
                    child=Label(label="Open Usage"),
                    on_clicked=lambda *_: open_ai_usage_url(provider),
                ),
                Button(
                    name="ai-footer-button",
                    child=Label(label="Refresh"),
                    on_clicked=lambda *_: self.restart_monitor_and_refresh(),
                ),
                Button(
                    name="ai-footer-button",
                    child=Label(label="Switch"),
                    on_clicked=lambda *_: self.select_provider(next_ai_provider(provider)),
                ),
            ],
        )

    def select_provider(self, provider: str) -> None:
        save_ai_provider_preference(provider)
        self.restart_monitor_and_refresh()

    def refresh_after_provider_change(self) -> None:
        if self.on_provider_changed is not None:
            self.on_provider_changed()
        if self.get_visible():
            self.refresh()

    def restart_monitor_and_refresh(self) -> None:
        restart_ai_usage_monitor()
        self.refresh_after_provider_change()
        schedule_ai_provider_refreshes(self.refresh_after_provider_change)

    def toggle(self) -> None:
        if self.get_visible():
            self.hide()
            return
        self.refresh()
        self.show_all()


class CalendarPopout(Window):
    def __init__(self):
        self.calendar_label = Label(name="calendar-label", label="")
        super().__init__(
            name="calendar-popout",
            layer="top",
            geometry="top",
            margin="37px 0px 0px 0px",
            type_hint="dialog",
            visible=False,
            child=Box(
                name="calendar-panel",
                orientation="v",
                spacing=6,
                children=[
                    Label(name="popout-title", label="CALENDAR"),
                    self.calendar_label,
                ],
            ),
        )

    def toggle(self) -> None:
        if self.get_visible():
            self.hide()
            return
        self.calendar_label.set_label(calendar_text())
        self.show_all()


class StatusBar(Window):
    def __init__(self):
        super().__init__(
            name="fabric-awesomewm-bar",
            layer="top",
            geometry="top",
            type_hint="dock",
            size=bar_size_from_monitor_width(primary_monitor_width()),
            visible=False,
        )

        self.tasks = TaskStrip()
        self.popup_manager = PopupManager()
        self.network = StatusPill("NET", "...")
        self.volume = StatusPill("VOL", "...")
        self.audio_popout = AudioDevicePopout()
        self.volume_button = EventBox(
            name="volume-button",
            events=["button-press", "scroll"],
            child=self.volume,
        )
        self.volume_button.connect("button-press-event", self.on_volume_button_press)
        self.volume_button.connect("scroll-event", self.on_volume_scroll)
        self.ai = StatusPill("AI", "AI")
        self.ai_popout = AIUsagePopout(on_provider_changed=self.refresh_ai_usage)
        self.ai_button = EventBox(
            name="ai-button",
            events=["button-press"],
            child=self.ai,
        )
        self.ai_button.connect("button-press-event", self.on_ai_button_press)
        self.calendar_popout = CalendarPopout()
        self.register_popup("audio", self.audio_popout)
        self.register_popup("ai", self.ai_popout)
        self.register_popup("calendar", self.calendar_popout)
        self.dnd = StatusPill("DND", "off")
        self.dnd_button = Button(
            name="dnd-button",
            child=self.dnd,
            on_clicked=lambda *_: self.refresh_dnd(toggle_dnd()),
        )
        battery_initial = battery_value()
        self.battery = StatusPill("BAT", battery_initial) if battery_initial is not None else None

        end_children = [
            self.network,
            self.volume_button,
            self.ai_button,
        ]
        if self.battery is not None:
            end_children.append(self.battery)
        end_children.extend(
            [
                self.dnd_button,
                Button(
                    name="settings-button",
                    child=Label(label="SET"),
                    on_clicked=lambda *_: open_settings_launcher(),
                ),
            ]
        )

        self.children = CenterBox(
            name="bar-inner",
            h_expand=True,
            start_children=Box(
                name="start-container",
                orientation="h",
                spacing=8,
                h_expand=True,
                children=[
                    Button(
                        name="launcher-button",
                        tooltip_text="Launcher",
                        child=Label(label=">"),
                        on_clicked=lambda *_: open_launcher(),
                    ),
                    self.tasks,
                ],
            ),
            center_children=Box(
                name="center-container",
                h_expand=True,
                children=[
                    Button(
                        name="clock-button",
                        child=DateTime(name="date-time", formatters="%a %-d  %H:%M"),
                        on_clicked=lambda *_: self.popup_manager.toggle("calendar"),
                    )
                ],
            ),
            end_children=Box(
                name="end-container",
                orientation="h",
                spacing=8,
                h_expand=True,
                children=end_children,
            ),
        )

        self.pollers = [
            Fabricator(interval=2000, poll_from=lambda _: running_tasks(), on_changed=lambda _, value: self.tasks.set_tasks(value)),
            Fabricator(interval=10000, poll_from=lambda _: network_text(), on_changed=lambda _, value: self.network.set_value(value)),
            Fabricator(interval=VOLUME_POLL_MS, poll_from=lambda _: volume_text(), on_changed=lambda _, value: self.volume.set_value(value)),
            Fabricator(interval=AI_POLL_MS, poll_from=lambda _: ai_usage_text(), on_changed=lambda _, value: self.ai.set_value(value)),
            Fabricator(interval=3000, poll_from=lambda _: dnd_text(), on_changed=lambda _, value: self.refresh_dnd(value)),
        ]
        if self.battery is not None:
            self.pollers.append(
                Fabricator(interval=30000, poll_from=lambda _: battery_text(), on_changed=lambda _, value: self.battery.set_value(value))
            )

        self.tasks.set_tasks(running_tasks())
        self.network.set_value(network_text())
        self.volume.set_value(volume_text())
        self.refresh_ai_usage()
        self.refresh_dnd(dnd_text())

    def windows(self) -> list[Window]:
        return [self, self.audio_popout, self.ai_popout, self.calendar_popout]

    def register_popup(self, name: str, popup: Window) -> None:
        self.popup_manager.register(name, popup)
        popup.connect("focus-out-event", lambda *_args, target=name: self.on_popup_focus_out(target))
        popup.connect("key-press-event", lambda _widget, event, target=name: self.on_popup_key_press(target, event))

    def on_popup_focus_out(self, name: str) -> bool:
        self.popup_manager.close(name, reason="focus-out")
        return False

    def on_popup_key_press(self, name: str, event) -> bool:
        try:
            from gi.repository import Gdk

            if int(getattr(event, "keyval", 0)) == int(Gdk.KEY_Escape):
                self.popup_manager.close(name)
                return True
        except Exception:
            if str(getattr(event, "keyval", "")).lower() == "escape":
                self.popup_manager.close(name)
                return True
        return False

    def on_volume_button_press(self, _widget, event) -> bool:
        button = int(getattr(event, "button", 0))
        if button == 1:
            toggle_volume()
        elif button == 2:
            open_audio_mixer()
        elif button == 3:
            self.popup_manager.toggle("audio")
        return True

    def on_volume_scroll(self, _widget, event) -> bool:
        direction = str(getattr(event, "direction", "")).lower()
        if "up" in direction:
            change_volume(5)
        elif "down" in direction:
            change_volume(-5)
        return True

    def on_ai_button_press(self, _widget, event) -> bool:
        button = int(getattr(event, "button", 0))
        if button == 1 and event_has_shift(event):
            restart_ai_usage_monitor()
        elif button == 1:
            self.popup_manager.toggle("ai")
        elif button == 2:
            self.switch_ai_provider()
        elif button == 3:
            provider = load_ai_provider_preference()
            open_ai_usage_url(provider)
        return True

    def refresh_ai_usage(self) -> None:
        self.ai.set_value(ai_usage_text())

    def switch_ai_provider(self) -> None:
        save_ai_provider_preference(next_ai_provider(load_ai_provider_preference()))
        restart_ai_usage_monitor()
        self.refresh_after_ai_provider_change()
        schedule_ai_provider_refreshes(self.refresh_after_ai_provider_change)

    def refresh_after_ai_provider_change(self) -> None:
        self.refresh_ai_usage()
        if self.ai_popout.get_visible():
            self.ai_popout.refresh()

    def refresh_dnd(self, value: str) -> None:
        state = normalize_dnd_text(value)
        self.dnd.set_value(state)
        self.dnd_button.set_style_classes(["dnd-on"] if state == "on" else ["dnd-off"])


if __name__ == "__main__":
    if "--check" in sys.argv:
        raise SystemExit(run_self_check())

    bar = StatusBar()
    app = Application("fabric-awesomewm", *bar.windows())
    app.set_stylesheet_from_file(get_relative_path("./style.css"))
    bar.show_all()
    app.run()
