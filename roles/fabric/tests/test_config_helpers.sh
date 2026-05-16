#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python_bin="${FABRIC_TEST_PYTHON:-$HOME/.local/share/fabric-awesomewm/venv/bin/python}"
config_path="$repo_root/roles/fabric/files/config/awesomewm/config.py"
css_path="$repo_root/roles/fabric/files/config/awesomewm/style.css"

if [ ! -x "$python_bin" ]; then
  echo "missing test Python: $python_bin" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/status.json" <<'JSON'
{
  "claude": {
    "available": false,
    "five_hour": null,
    "error": "token_expired"
  },
  "codex": {
    "available": true,
    "session": {
      "utilization": 13.0
    }
  }
}
JSON

PYTHONDONTWRITEBYTECODE=1 "$python_bin" - "$config_path" "$tmpdir/status.json" "$css_path" <<'PY'
from __future__ import annotations

import importlib.util
import json
import pathlib
import re
import sys
from datetime import date

config_path = pathlib.Path(sys.argv[1])
status_path = pathlib.Path(sys.argv[2])
css_path = pathlib.Path(sys.argv[3])

spec = importlib.util.spec_from_file_location("fabric_awesomewm_config", config_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)

module.AI_STATUS_PATH = status_path
module.AI_PROVIDER_PREF_PATH = status_path.parent / "provider.txt"
module.AI_PROVIDER_PREF_PATH.write_text("codex\n")
module.codex_live_usage_text = lambda: None
assert module.launcher_command() == ["awesome-client", "awesome.emit_signal('techdufus::launcher_root')"]
assert module.settings_command() == ["awesome-client", "awesome.emit_signal('techdufus::launcher_settings')"]
assert module.ai_usage_text() == "13%"
assert module.VOLUME_POLL_MS <= 1000
assert module.AI_POLL_MS <= 5000
assert module.bar_size_from_monitor_width(1920) == (1920, 37)
assert module.bar_size_from_monitor_width(1) == (1, 37)
fallback_monitors = module.fallback_monitor_geometries()
assert fallback_monitors == [
    module.MonitorGeometry(index=0, x=0, y=0, width=1920, height=1080, scale_factor=1, primary=True, name="fallback")
]

codex_rate_limits = {
    "limit_id": "codex",
    "primary": {
        "used_percent": 42.0,
        "resets_at": 1778679000,
    },
    "secondary": {
        "used_percent": 3.0,
        "resets_at": 1779283800,
    },
}
token_count_line = json.dumps(
    {
        "type": "event_msg",
        "payload": {
            "type": "token_count",
            "info": {
                "rate_limits": codex_rate_limits,
            },
        },
    }
)
assert module.codex_usage_from_rate_limits(codex_rate_limits) == "42%"
assert module.codex_usage_text_from_lines(["{}", token_count_line]) == "42%"
assert module.codex_usage_from_rate_limits({"limit_id": "codex", "primary": {"used_percent": 0.0}}) == "0%"

ai_summary = module.ai_summary_from_status(
    {
        "timestamp": "2026-05-13T13:30:00Z",
        "codex": {
            "available": True,
            "session": {"utilization": 13.0, "resets_at": "2026-05-13T18:06:12Z"},
            "weekly": {"utilization": 3.0, "resets_at": "2026-05-19T01:20:52Z"},
            "error": None,
        },
        "claude": {"available": False, "five_hour": None, "error": "token_expired"},
        "errors": ["token_expired"],
    }
)
assert ai_summary["provider"] == "codex"
assert ai_summary["session"] == "13%"
assert ai_summary["weekly"] == "3%"
assert ai_summary["session_resets_at"] == "2026-05-13T18:06:12Z"
assert ai_summary["weekly_resets_at"] == "2026-05-19T01:20:52Z"
assert ai_summary["timestamp"] == "2026-05-13T13:30:00Z"
assert ai_summary["errors"] == ["token_expired"]

provider_pref = tmpdir_path = status_path.parent / "provider.txt"
assert module.normalize_ai_provider("claude") == "claude"
assert module.normalize_ai_provider("codex") == "codex"
assert module.normalize_ai_provider("bogus") == "codex"
assert module.load_ai_provider_preference(provider_pref) == "codex"
provider_pref.write_text("claude\n")
assert module.load_ai_provider_preference(provider_pref) == "claude"
module.save_ai_provider_preference("codex", provider_pref)
assert provider_pref.read_text() == "codex\n"
assert module.next_ai_provider("codex") == "claude"
assert module.next_ai_provider("claude") == "codex"

assert module.usage_severity(None) == "unknown"
assert module.usage_severity(12.4) == "cool"
assert module.usage_severity(64) == "warm"
assert module.usage_severity(76) == "hot"
assert module.usage_severity(96) == "critical"

assert module.percent_display(13.0) == "13%"
assert module.percent_display(13.4) == "13%"
assert module.percent_display(13.5) == "14%"
assert module.progress_value(42.0) == 0.42
assert module.progress_value(142.0) == 1.0
assert module.progress_value(-3.0) == 0.0
assert module.metric_percent({"utilization": 0.0}) == 0.0

reset_text = module.format_reset_text("2026-05-13T18:06:12Z", now_epoch=1778691912)
assert reset_text.startswith("resets in 1h 01m")
assert "(" in reset_text and ")" in reset_text
assert module.format_reset_text(None, now_epoch=1778691912) == "reset unknown"

dashboard_status = {
    "timestamp": "2026-05-13T16:53:06Z",
    "claude": {
        "available": False,
        "five_hour": None,
        "seven_day": None,
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "extra_usage": None,
        "error": "token_expired",
    },
    "codex": {
        "available": True,
        "session": {"utilization": 13.0, "resets_at": "2026-05-13T18:06:12Z"},
        "weekly": {"utilization": 3.0, "resets_at": "2026-05-19T01:20:52Z"},
        "error": None,
    },
    "errors": ["token_expired"],
}
codex_model = module.ai_dashboard_model(dashboard_status, "codex", now_epoch=1778691912)
assert codex_model["active_provider"] == "codex"
assert codex_model["title"] == "Codex Usage"
assert codex_model["status_messages"] == []
assert [row["label"] for row in codex_model["rows"]] == ["Session", "Weekly"]
assert codex_model["rows"][0]["percent_text"] == "13%"
assert codex_model["rows"][0]["severity"] == "cool"
assert codex_model["rows"][0]["reset_text"].startswith("resets in 1h 01m")
assert codex_model["tabs"] == [
    {"provider": "claude", "label": "Claude", "active": False, "available": False, "error": "token_expired"},
    {"provider": "codex", "label": "Codex", "active": True, "available": True, "error": ""},
]

claude_model = module.ai_dashboard_model(dashboard_status, "claude", now_epoch=1778691912)
assert claude_model["active_provider"] == "claude"
assert claude_model["title"] == "Claude Usage"
assert claude_model["rows"] == []
assert claude_model["status_messages"] == ["Claude unavailable: token_expired"]

stale_claude_status = {
    "active_provider": "claude",
    "claude": {"available": False, "five_hour": None, "error": "token_expired"},
    "codex": {"available": False, "session": None, "weekly": None, "error": "inactive"},
    "errors": ["token_expired"],
}
codex_pending_model = module.ai_dashboard_model(stale_claude_status, "codex", now_epoch=1778691912)
assert codex_pending_model["rows"] == []
assert codex_pending_model["status_messages"] == ["Refreshing Codex usage..."]
assert module.ai_compact_usage_from_status(stale_claude_status, "codex", live_codex=None) == "..."

assert module.ai_compact_usage_from_status(dashboard_status, "codex", live_codex="42%") == "42%"
assert module.ai_compact_usage_from_status(dashboard_status, "codex", live_codex=None) == "13%"
assert module.ai_compact_usage_from_status(dashboard_status, "claude", live_codex="42%") == "--"
live_model = module.ai_dashboard_model(module.status_with_live_codex_usage(dashboard_status, "42%"), "codex", now_epoch=1778691912)
assert live_model["rows"][0]["percent_text"] == "42%"
assert live_model["primary_percent_text"] == "42%"

scheduled_refreshes = []
refresh_calls = []


def fake_scheduler(delay, callback):
    scheduled_refreshes.append(delay)
    refresh_calls.append(callback())
    return len(scheduled_refreshes)


assert module.schedule_ai_provider_refreshes(lambda: None, scheduler=fake_scheduler) is True
assert scheduled_refreshes == list(module.AI_PROVIDER_SWITCH_REFRESH_DELAYS_MS)
assert refresh_calls == [False, False]

module.AI_PROVIDER_PREF_PATH.write_text("claude\n")
live_scan_calls = {"count": 0}


def fail_if_live_codex_scans():
    live_scan_calls["count"] += 1
    raise AssertionError("Codex live scanner should not run while Claude is active")


module.codex_live_usage_text = fail_if_live_codex_scans
assert module.ai_usage_text() == "--"
assert live_scan_calls["count"] == 0

module.AI_PROVIDER_PREF_PATH.write_text("codex\n")
module.codex_live_usage_text = lambda: "42%"
assert module.ai_usage_text() == "42%"

awesome_stdout = '''   string "fabric\tConfig.py\tfalse\t41943040\tfalse
Family - HomeLab - 1Password\t1Password\tfalse\t41943041\tfalse
tmux\tcom.mitchellh.ghostty\tfalse\t41943042\ttrue
tmux\tcom.mitchellh.ghostty\ttrue\t41943043\tfalse
Untitled - Chromium\tChromium-browser\tfalse\t41943044\tfalse
/home/techdufus/.config/fabric/awesomewm/config.py\tpython3\tfalse\t41943045\tfalse"'''
tasks = module.parse_awesome_clients(awesome_stdout)
assert tasks == [
    {"label": "1Password", "class_name": "1Password", "minimized": False, "window_id": "41943041", "focused": False},
    {"label": "Ghostty", "class_name": "com.mitchellh.ghostty", "minimized": False, "window_id": "41943042", "focused": True},
    {"label": "Ghostty", "class_name": "com.mitchellh.ghostty", "minimized": True, "window_id": "41943043", "focused": False},
    {"label": "Chromium", "class_name": "Chromium-browser", "minimized": False, "window_id": "41943044", "focused": False},
]
assert module.task_button_labels(tasks) == ["1Password", "Ghostty", "Ghostty 2", "Chromium"]
assert module.tasks_text(tasks) == "1Password  Ghostty  Ghostty 2  Chromium"
assert module.parse_awesome_clients('string "Fabric\tfabric-awesomewm\tfalse\t11\tfalse"') == []

grouped = module.group_tasks_for_dock(tasks, max_icons=3)
assert grouped == [
    {
        "label": "1Password",
        "class_name": "1Password",
        "window_ids": ["41943041"],
        "count": 1,
        "focused": False,
    },
    {
        "label": "Ghostty",
        "class_name": "com.mitchellh.ghostty",
        "window_ids": ["41943042", "41943043"],
        "count": 2,
        "focused": True,
    },
    {
        "label": "Chromium",
        "class_name": "Chromium-browser",
        "window_ids": ["41943044"],
        "count": 1,
        "focused": False,
    },
]
assert module.overflow_count_for_tasks(tasks, max_icons=2) == 1
assert module.icon_name_for_class("com.mitchellh.ghostty") in {"com.mitchellh.ghostty", "utilities-terminal", "terminal"}
assert module.icon_name_for_class("") == "application-x-executable"
assert module.initials_for_label("1Password") == "1"
assert module.initials_for_label("Chromium") == "C"
assert module.initials_for_label("Visual Studio Code") == "VS"

assert module.network_label_from_interface("enp5s0") == "LAN"
assert module.network_label_from_interface("wlp0s20f3") == "WIFI"
assert module.network_label_from_interface("tailscale0") == "VPN"
assert module.network_label_from_interface("tun0") == "VPN"
assert module.network_label_from_interface("") == "OFF"

assert module.normalize_dnd_text('string "on"') == "on"
assert module.normalize_dnd_text('string "off"') == "off"
assert module.normalize_dnd_text("true") == "on"
assert module.normalize_dnd_text("") == "off"

assert module.battery_value_from_output("83%") == "83%"
assert module.battery_value_from_output("") is None
assert module.battery_value_from_output("   ") is None

audio_listing = """default_sink\talsa_output.usb.DAC
sink\talsa_output.usb.DAC
sink\talsa_output.pci.hdmi
default_source\talsa_input.usb.Mic
source\talsa_input.usb.Mic
source\talsa_input.pci.analog
"""
parsed_audio = module.parse_audio_devices(audio_listing)
assert parsed_audio["default_sink"] == "alsa_output.usb.DAC"
assert parsed_audio["sinks"] == ["alsa_output.usb.DAC", "alsa_output.pci.hdmi"]
assert parsed_audio["default_source"] == "alsa_input.usb.Mic"
assert parsed_audio["sources"] == ["alsa_input.usb.Mic", "alsa_input.pci.analog"]

calendar_output = "      May 2026\\nSu Mo Tu We Th Fr Sa\\n                1  2"
assert module.calendar_text_from_output(calendar_output) == calendar_output
assert module.calendar_text_from_output("") == "calendar unavailable"
rendered_calendar = module.calendar_text_for_months(2026, 5)
assert "May 2026" in rendered_calendar
assert "June 2026" in rendered_calendar
assert "1  2" in rendered_calendar
assert callable(getattr(module.CalendarPopout, "refresh", None))

calendar_model = module.calendar_month_model(
    2026,
    5,
    today=date(2026, 5, 14),
    selected=date(2026, 5, 14),
    marker_days={date(2026, 5, 1), date(2026, 5, 15)},
)
assert calendar_model["title"] == "May 2026"
assert calendar_model["selected_label"] == "Thu May 14, 2026"
assert len(calendar_model["weeks"]) == 6
assert all(len(week) == 7 for week in calendar_model["weeks"])
assert calendar_model["weeks"][0][0]["date"] == date(2026, 4, 26)
selected_day = calendar_model["weeks"][2][4]
assert selected_day["day"] == "14"
assert selected_day["style_classes"] == ["current-month", "today", "selected"]
marked_day = calendar_model["weeks"][0][5]
assert marked_day["date"] == date(2026, 5, 1)
assert "has-marker" in marked_day["style_classes"]
assert module.shifted_date_by_days(date(2026, 5, 1), -7) == date(2026, 4, 24)
assert module.shifted_date_by_days(date(2026, 12, 29), 7) == date(2027, 1, 5)
assert module.calendar_action_for_key("h") == "month-prev"
assert module.calendar_action_for_key("Left") == "month-prev"
assert module.calendar_action_for_key("l") == "month-next"
assert module.calendar_action_for_key("Right") == "month-next"
assert module.calendar_action_for_key("k") == "week-prev"
assert module.calendar_action_for_key("Up") == "week-prev"
assert module.calendar_action_for_key("j") == "week-next"
assert module.calendar_action_for_key("Down") == "week-next"
assert module.calendar_action_for_key("t") == "today"
assert module.calendar_action_for_key("Return") == "today"
assert module.calendar_action_for_key("space") is None

now = [100.0]


class DummyPopup:
    def __init__(self):
        self.visible = False
        self.refresh_count = 0
        self.show_count = 0
        self.hide_count = 0
        self.present_count = 0

    def get_visible(self):
        return self.visible

    def refresh(self):
        self.refresh_count += 1

    def show_all(self):
        self.visible = True
        self.show_count += 1

    def hide(self):
        self.visible = False
        self.hide_count += 1

    def present(self):
        self.present_count += 1


audio_popup = DummyPopup()
ai_popup = DummyPopup()
calendar_popup = DummyPopup()
manager = module.PopupManager(clock=lambda: now[0], reopen_suppression_seconds=0.5)
manager.register("audio", audio_popup)
manager.register("ai", ai_popup)
manager.register("calendar", calendar_popup)

manager.toggle("audio")
assert audio_popup.visible is True
assert audio_popup.refresh_count == 1
assert audio_popup.present_count == 1
assert manager.active_name == "audio"

manager.toggle("ai")
assert audio_popup.visible is False
assert ai_popup.visible is True
assert manager.active_name == "ai"

manager.toggle("ai")
assert ai_popup.visible is False
assert manager.active_name is None

manager.open("calendar")
manager.close("calendar", reason="focus-out")
assert calendar_popup.visible is False
manager.toggle("calendar")
assert calendar_popup.visible is False
now[0] += 0.6
manager.toggle("calendar")
assert calendar_popup.visible is True

manager.close_all()
assert audio_popup.visible is False
assert ai_popup.visible is False
assert calendar_popup.visible is False
assert manager.active_name is None

css = css_path.read_text()
assert "#fabric-awesomewm-bar" in css
assert "#bar-inner" in css
assert "border-bottom" in css
assert "min-width: 248px" not in css
assert "border-radius: 999px" not in css

bar_inner = re.search(r"#bar-inner\s*\{(?P<body>.*?)\}", css, re.S)
assert bar_inner is not None
bar_body = bar_inner.group("body")
assert "background-color: alpha(var(--base), 0.97)" in bar_body
assert "border-bottom: 2px solid alpha(var(--cyan), 0.55)" in bar_body
assert "padding: 3px 10px" in bar_body

task_strip = re.search(r"#task-strip\s*\{(?P<body>.*?)\}", css, re.S)
assert task_strip is not None
assert "min-width" not in task_strip.group("body")
for selector in (
    "#ai-panel",
    "#ai-provider-tabs",
    "#ai-provider-tab",
    "#ai-metric-row",
    "#ai-progress",
    "#ai-footer-button",
    "#calendar-header",
    "#calendar-grid",
    "#calendar-day",
    "#calendar-day.today",
    "#calendar-day.selected",
    "#calendar-day.has-marker",
    "#calendar-selected",
    "#calendar-hints",
):
    assert selector in css
PY

bash -n "$repo_root/roles/fabric/files/bin/fabric-awesomewm"
grep -q -- "--replace" "$repo_root/roles/fabric/files/bin/fabric-awesomewm"
grep -q "pkill -u" "$repo_root/roles/fabric/files/bin/fabric-awesomewm"
