#!/usr/bin/env python3
from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import sys
import tomllib
import unittest
import jinja2
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE = REPO_ROOT / "roles" / "plasma"
HELPER = ROLE / "files" / "bin" / "plasma-summon-service.py"
KWIN_SCRIPT = ROLE / "files" / "kwin" / "plasma-summon" / "contents" / "code" / "main.js"
GROUP_VARS = REPO_ROOT / "group_vars" / "all.yml"
KWIN_METADATA = ROLE / "files" / "kwin" / "plasma-summon" / "metadata.json"
SUMMON_DIR = ROLE / "files" / "summon"
AWESOME_POSITIONS = REPO_ROOT / "roles" / "awesomewm" / "files" / "config" / "cell-management" / "positions.lua"
HAMMERSPOON_POSITIONS = REPO_ROOT / "roles" / "hammerspoon" / "files" / "config" / "positions.lua"

loader = importlib.machinery.SourceFileLoader("plasma_summon_service", str(HELPER))

spec = importlib.util.spec_from_loader(loader.name, loader)
plasma_summon_service = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = plasma_summon_service
loader.exec_module(plasma_summon_service)


def load_toml(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))

def render_keyd_template(source: str, variant: str) -> str:
    return jinja2.Environment(autoescape=False, lstrip_blocks=True, trim_blocks=True).from_string(source).render(
        keyboard={"variant": variant},
    )


class PlasmaRoleConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = (ROLE / "tasks" / "main.yml").read_text(encoding="utf-8")
        cls.arch_tasks = (ROLE / "tasks" / "Archlinux.yml").read_text(encoding="utf-8")
        cls.defaults = (ROLE / "defaults" / "main.yml").read_text(encoding="utf-8")
        cls.group_vars = GROUP_VARS.read_text(encoding="utf-8")
        cls.script = KWIN_SCRIPT.read_text(encoding="utf-8")
        cls.metadata = json.loads(KWIN_METADATA.read_text(encoding="utf-8"))
        cls.service = (ROLE / "files" / "systemd" / "plasma-summon.service").read_text(encoding="utf-8")
        cls.keyd_template = (ROLE / "templates" / "keyd" / "default.conf.j2").read_text(encoding="utf-8")
        cls.keyd_config = render_keyd_template(cls.keyd_template, "dvorak")
        cls.keyd_qwerty_config = render_keyd_template(cls.keyd_template, "")
        cls.apps = load_toml(SUMMON_DIR / "apps.toml")["apps"]
        cls.regions = load_toml(SUMMON_DIR / "regions.toml")["regions"]
        cls.layouts = load_toml(SUMMON_DIR / "layouts.toml")["layouts"]
        cls.keyd_bridge = (ROLE / "templates" / "bin" / "plasma-summon-keyd.j2").read_text(encoding="utf-8")

    def test_arch_role_installs_normal_plasma_wayland_stack(self) -> None:
        for package in [
            "plasma-meta",
            "sddm",
            "xdg-desktop-portal-kde",
            "qt6-wayland",
            "xorg-xwayland",
            "dolphin",
            "systemsettings",
            "kpackage",
            "kconfig",
            "python-dbus-next",
            "fuzzel",
            "keyd",
            "rofimoji",
            "rofi",
            "wl-clipboard",
            "noto-fonts-emoji",
        ]:
            self.assertIn(package, self.defaults)
        self.assertIn("community.general.pacman", self.arch_tasks)
        self.assertIn("can_install_packages | default(false)", self.arch_tasks)
        self.assertIn("Enable SDDM display manager", self.arch_tasks)

    def test_arch_role_maps_capslock_to_f13_with_keyd(self) -> None:
        for required in [
            "plasma_enable_capslock_f13: true",
            "plasma_capslock_f13_arch_packages:",
            "Install CapsLock to F13 remapper packages",
            "Ensure keyd config directory exists",
            "Ensure keyd macro bridge directory exists",
            "Install keyd macro bridge",
            "ansible.builtin.template",
            "bin/plasma-summon-keyd.j2",
            "/usr/local/bin/plasma-summon-keyd",
            "/etc/keyd",
            "Map CapsLock to F13 with keyd",
            "keyd/default.conf.j2",
            "/etc/keyd/default.conf",
            "Enable keyd CapsLock to F13 remap",
            "keyd.service",
        ]:
            self.assertIn(required, self.defaults + self.arch_tasks)
        self.assertIn("[ids]\n*", self.keyd_config)
        self.assertIn("oneshot_timeout = 2000", self.keyd_config)
        self.assertIn("capslock = overload(plasma_summon, oneshot(plasma_leader))", self.keyd_config)
        self.assertIn("f13 = overload(plasma_summon, oneshot(plasma_leader))", self.keyd_config)
        self.assertIn("[plasma_summon]", self.keyd_config)
        # Dvorak logical app keys arrive as different physical keyd keys:
        # logical t -> physical k, b -> n, s -> semicolon.
        self.assertIn("k = macro(f13 k)", self.keyd_config)
        self.assertIn("n = macro(f13 n)", self.keyd_config)
        self.assertIn("semicolon = macro(f13 semicolon)", self.keyd_config)
        self.assertIn("b = macro(f13 b)", self.keyd_qwerty_config)
        self.assertIn("[plasma_leader]", self.keyd_config)
        self.assertIn("[plasma_macro_action]", self.keyd_config)

    def test_keyd_double_tap_route_runs_macros_without_breaking_summon(self) -> None:
        self.assertIn("[plasma_leader]", self.keyd_config)
        self.assertIn("t = macro(f13 t)", self.keyd_config)
        self.assertIn("s = macro(f13 s)", self.keyd_config)
        self.assertIn("capslock = oneshot(plasma_macro_action)", self.keyd_config)
        self.assertIn("f13 = oneshot(plasma_macro_action)", self.keyd_config)
        self.assertIn("[plasma_macro_action]", self.keyd_config)
        self.assertIn("a = command(/usr/local/bin/plasma-summon-keyd run cycle_same_app)", self.keyd_config)
        self.assertIn("semicolon = command(/usr/local/bin/plasma-summon-keyd run screenshot_area)", self.keyd_config)
        self.assertIn("d = command(/usr/local/bin/plasma-summon-keyd run emoji_picker)", self.keyd_config)
        self.assertNotIn("s = command(/usr/local/bin/plasma-summon-keyd run screenshot_area)", self.keyd_config)
        self.assertIn("s = command(/usr/local/bin/plasma-summon-keyd run screenshot_area)", self.keyd_qwerty_config)
        self.assertIn("e = command(/usr/local/bin/plasma-summon-keyd run emoji_picker)", self.keyd_qwerty_config)
        self.assertIn("esc = clear()", self.keyd_config)
        self.assertIn("f13 = clear()", self.keyd_config)
        self.assertIn("capslock = clear()", self.keyd_config)
        self.assertNotIn("[plasma_hold]", self.keyd_config)
        self.assertNotIn("oneshotm(plasma_macro, macro(f13))", self.keyd_config)
        self.assertNotIn("toggle(plasma_macro_action)", self.keyd_config)
        self.assertNotIn("macro(f16 e)", self.keyd_config)
        self.assertNotIn("macro(f16 s)", self.keyd_config)

    def test_keyd_macro_bridge_runs_whitelisted_user_session_actions(self) -> None:
        self.assertIn("PLASMA_SUMMON_USER=\"{{ ansible_facts['user_id'] }}\"", self.keyd_bridge)
        self.assertIn("PLASMA_SUMMON_SERVICE=\"{{ plasma_local_bin_dir }}/plasma-summon-service\"", self.keyd_bridge)
        self.assertIn("PLASMA_SUMMON_KEYD_DRY_RUN", self.keyd_bridge)
        self.assertIn("Do not run `keyd do clear()`", self.keyd_bridge)
        self.assertNotIn("keyd_clear()", self.keyd_bridge)
        self.assertNotIn("do 'clear()'", self.keyd_bridge)
        self.assertIn("run_user \"${PLASMA_SUMMON_SERVICE}\" --macro \"$1\"", self.keyd_bridge)
        self.assertIn("org.kde.kglobalaccel.Component.invokeShortcut", self.keyd_bridge)
        self.assertIn("\"Macro a via F16\"", self.keyd_bridge)

    def test_sddm_enablement_preserves_existing_display_manager(self) -> None:
        for required in [
            "Detect configured display manager",
            "/etc/systemd/system/display-manager.service",
            "plasma_display_manager_unit.stat.exists | default(false)",
            "plasma_display_manager_unit.stat.lnk_target | default('') | basename",
            "Keep existing display manager",
            "Disable that display manager first if you want SDDM",
        ]:
            self.assertIn(required, self.arch_tasks)


    def test_role_manages_stable_plasma_desktop_settings(self) -> None:
        for required in [
            "plasma_manage_desktop_settings: true",
            "Sparse KConfig writes for stable desktop preferences.",
            "plasma_desktop_kconfig_settings:",
            "group_path: [Keyboard]",
            "file: kcminputrc",
            "key: RepeatDelay",
            "value: \"400\"",
            "key: RepeatRate",
            "value: \"30\"",
            "group_path: [Mouse]",
            "key: cursorTheme",
            "value: Sweet-cursors",
            "file: plasmanotifyrc",
            "group_path: [Notifications]",
            "key: PopupTimeout",
            "value: \"4000\"",
            "file: kwinrc",
            "group_path: [Plugins]",
            "key: blurEnabled",
            "key: mouseclickEnabled",
            "key: ElectricBorders",
            "key: library",
            "value: org.kde.oxygen",
            "file: kdeglobals",
            "key: BrowserApplication",
            "value: brave-browser.desktop",
            "key: TerminalApplication",
            "value: /usr/bin/ghostty --gtk-single-instance=true",
            "key: Theme",
            "value: candy-icons",
            "key: AnimationDurationFactor",
            "value: \"0.125\"",
            "file: plasma-localerc",
            "file: powerdevilrc",
            "group_path: [AC, Display]",
            "group_path: [AC, SuspendAndShutdown]",
            "key: AutoSuspendIdleTimeoutSec",
            "value: \"5400\"",
        ]:
            self.assertIn(required, self.defaults)
        for required in [
            "Validate role-managed Plasma desktop settings",
            "Configure role-managed Plasma desktop settings",
            "kwriteconfig6",
            "{{ plasma_desktop_kconfig_settings }}",
            "plasma_manage_desktop_settings | bool",
            "item.group_path is sequence",
            "item.group_path is not string",
            "item.value is string",
            "{% for group in item.group_path %}",
            "--group {{ group | quote }}",
            "item.group_path | join('/')",
        ]:
            self.assertIn(required, self.tasks)
        self.assertNotIn("plasma_desktop_nested_kconfig_settings", self.defaults)
        self.assertNotIn("item.groups[0]", self.tasks)


    def test_role_owns_plasma_summon_runtime_paths(self) -> None:
        for required in [
            "files/bin/plasma-summon-service.py",
            "{{ plasma_local_bin_dir }}/plasma-summon-service",
            "files/summon/apps.toml",
            "files/summon/regions.toml",
            "files/summon/layouts.toml",
            "{{ plasma_config_dir }}/apps.toml",
            "{{ plasma_config_dir }}/regions.toml",
            "{{ plasma_config_dir }}/layouts.toml",
            "files/systemd/plasma-summon.service",
            "{{ plasma_systemd_user_dir }}/plasma-summon.service",
            "files/kwin/{{ plasma_summon_script_id }}",
            "{{ plasma_kwin_scripts_dir }}/{{ plasma_summon_script_id }}",
            "{{ plasma_summon_script_id }}Enabled",
            "Reserve Tools key for Plasma summon",
            "systemsettings.desktop",
            "_launch",
            "none,Tools\\tMeta+I,System Settings",
            "Configure Plasma summon KWin shortcuts",
            "Move Active to Cell 1",
            "Move Active to Region main",
            "Cycle Active Screen Layout",
            "Pick Active Window Region",
            "none,none,Pick region/cell for active window",
            "Pick Active Screen Layout",
            "none,none,Pick active screen layout",
            "Open Plasma Summon Window Mover",
            "Meta+U,none,Pick region/cell for active window",
            "Hide Active Window",
            "Meta+H,none,Minimize active window",
            "Open Plasma Summon Layout Picker",
            "Meta+Alt+Ctrl+Shift+P,none,Pick active screen layout",
            "Ask KGlobalAccel to release System Settings Tools shortcut",
            "/component/systemsettings_desktop",
            "Unload existing Plasma summon KWin script",
            "org.kde.kwin.Scripting.unloadScript",
            "Load Plasma summon into running KWin",
            "org.kde.kwin.Scripting.loadScript",
            "{{ plasma_kwin_scripts_dir }}/{{ plasma_summon_script_id }}/contents/code/main.js",
            "Start pending KWin scripts",
            "org.kde.kwin.Scripting.start",
            "Configure running Plasma summon shortcuts",
            "--configure-shortcuts",
            "kwriteconfig6",
            "qdbus6",
            "rofimoji.rc",
            "{{ ansible_facts['user_dir'] }}/.config/rofimoji.rc",
        ]:
            self.assertIn(required, self.tasks)
        self.assertIn("plasma_summon_script_id: plasma-summon", self.defaults)
        self.assertIn("ExecStart=%h/.local/bin/plasma-summon-service", self.service)
        self.assertIn("WantedBy=graphical-session.target", self.service)
        for required in [
            "Import Plasma graphical environment into user services",
            "dbus-update-activation-environment",
            "WAYLAND_DISPLAY",
            "XDG_CURRENT_DESKTOP",
            "Remove legacy default-target summon service enablement",
            "default.target.wants/plasma-summon.service",
            "Enable and restart Plasma summon service",
            "state: restarted",
        ]:
            self.assertIn(required, self.tasks)

    def test_role_manages_rofimoji_copy_config(self) -> None:
        config_sources = [ROLE / "files" / "rofimoji.rc", ROLE / "templates" / "rofimoji.rc.j2"]
        self.assertTrue(any(path.exists() for path in config_sources))
        config = next(path for path in config_sources if path.exists()).read_text(encoding="utf-8")
        for required in [
            "selector=rofi",
            "action=copy",
            "clipboarder=wl-copy",
            "skin-tone=neutral",
        ]:
            self.assertIn(required, config)

    def test_role_does_not_manage_login_time_output_wakeup(self) -> None:
        for obsolete in [
            "plasma_start_output_wakeup_service",
            "plasma_output_wakeup_hosts",
            "plasma_output_wakeup_connectors",
            "plasma_output_wakeup_delay",
            "plasma_output_wakeup_settle",
        ]:
            self.assertNotIn(obsolete, self.defaults)
            self.assertNotIn(obsolete, self.group_vars)
            self.assertNotIn(obsolete, self.tasks)
        for obsolete in [
            "files/bin/plasma-output-wakeup",
            "plasma-output-wakeup.service",
            "systemd/plasma-output-wakeup.service.j2",
            "Validate Plasma output wake",
            "Template Plasma output wake service",
            "Enable and restart Plasma output wake service",
            "Disable Plasma output wake service",
            "Remove Plasma output wake service",
        ]:
            self.assertNotIn(obsolete, self.tasks)
        self.assertFalse((ROLE / "files" / "bin" / "plasma-output-wakeup").exists())
        self.assertFalse((ROLE / "templates" / "systemd" / "plasma-output-wakeup.service.j2").exists())



    def test_kwin_package_metadata_matches_plasma_6_format(self) -> None:
        self.assertEqual(self.metadata["KPlugin"]["Id"], "plasma-summon")
        self.assertEqual(self.metadata["X-Plasma-API"], "javascript")
        self.assertEqual(self.metadata["X-Plasma-MainScript"], "code/main.js")
        self.assertEqual(self.metadata["KPackageStructure"], "KWin/Script")

    def test_kwin_script_registers_summon_region_layout_and_monitor_shortcuts(self) -> None:
        for required in [
            'registerShortcut("Summon " + appName',
            'const triggerPrefixes = ["F13", "CapsLock", "Tools"]',
            'prefix + "," + key',
            'registerShortcut("Open Plasma Summon Window Mover"',
            '"Meta+U", showCellPicker',
            'requestPicker("Move", options',
            '"PickOption"',
            'registerShortcut("Move Active Window to Next Screen"',
            '"Meta+O"',
            'registerShortcut("Move Active Window to Previous Screen"',
            '"Meta+Shift+O"',
            'registerShortcut("Hide Active Window"',
            '"Meta+H", hideActiveWindow',
            'registerShortcut("Open Plasma Summon Layout Picker"',
            '"Meta+Alt+Ctrl+Shift+P", showLayoutPicker',
            '"Meta+Alt+Ctrl+Shift+;"',
            "\"Meta+Alt+Ctrl+Shift+'\"",
            'registerShortcut("Reload Plasma Summon Configuration Hyper"',
            '"Meta+Alt+Ctrl+Shift+R"',
        ]:
            self.assertIn(required, self.script)
        for invalid in [
            'registerShortcut("Pick Active Window Region"',
            'registerShortcut("Pick Active Screen Layout"',
            "XF86Tools",
            "Meta+Alt+Ctrl+Shift+Semicolon",
            "Meta+Alt+Ctrl+Shift+Apostrophe",
            'registerShortcut("Move Active to Region " + regionName',
            '"Meta+U," + key',
            'registerShortcut("Move Active to Cell " + cell',
            '"Meta+U," + cell',
        ]:
            self.assertNotIn(invalid, self.script)

    def test_kwin_script_registers_f16_macro_shortcuts(self) -> None:
        for required in [
            "function sameAppKey(window)",
            "function cycleSameAppWindow()",
            "focusWindow(matches[(activeIndex + 1) % matches.length])",
            "function runMacro(macroName)",
            '"RunMacro"',
            "function registerMacroShortcuts()",
            "const macroActions = [",
            '{ key: "a", description: "Cycle windows of the active app", callback: cycleSameAppWindow }',
            '{ key: "s", description: "Capture a screenshot region to the clipboard", macro: "screenshot_area" }',
            '{ key: "e", description: "Open the Plasma emoji picker", macro: "emoji_picker" }',
            'const macroTriggerPrefixes = ["F16", "XF86Launch5", "Tools,Tools"]',
            "function macroActionCallback(action)",
            'prefix + "," + key',
            "registerMacroShortcuts();",
        ]:
            self.assertIn(required, self.script)

    def test_kwin_script_toggles_active_summon_back_to_previous_app(self) -> None:
        for required in [
            "previousWindowId",
            "function rememberWindowForApp(window)",
            "state.lastByApp[appName] = id",
            "function previousWindowForToggle(appName)",
            "function rememberPreviousWindow(previous, next)",
            "if (!place && normalWindow(active) && appMatches(active, appConfig))",
            "const previous = previousWindowForToggle(appName)",
            "focusWindow(previous)",
            "rememberWindowForApp(window);",
        ]:
            self.assertIn(required, self.script)



    def test_kwin_script_places_newly_launched_apps_with_current_layout_cells(self) -> None:
        for required in [
            "pendingLaunches",
            "function outputByName(name)",
            "function targetOutputForApp(appConfig, fallback)",
            "function placeAppWindow(appName, window)",
            "placeManagedAppWindowOnOutput(appName, window, targetOutput, false)",
            "configuredAppCell(output, pair[0], pair[1], appName)",
            "function placeWindowInLayoutCell(window, cellIndex, output, rememberOverride)",
            "placeWindowInLayoutCell(window, cellIndex, output, true)",
            "rememberPendingLaunch(appName, Boolean(place || appConfig.region || appConfig.monitor))",
            "launchApp(appName, true)",
            "summonApp(appName, false)",
            "workspace.windowAdded.connect(handleWindowAdded)",
            "workspace.clientAdded.connect(handleWindowAdded)",
            "prepareWindowForGeometry(window, region)",
            "window.setMaximize(false, false)",
            "window.quickTileMode = 0",
        ]:
            self.assertIn(required, self.script)
        self.assertNotIn("summonApp(appName, true)", self.script)
        self.assertIn('if ("fullScreen" in window && window.fullScreen)', self.script)
        self.assertIn("window.fullScreen = false", self.script)
        self.assertNotIn("refusing to move fullscreen window", self.script)
        self.assertIn("placeManagedWindowOnOutput(window, output, false)", self.script)
        self.assertNotIn("placeWindowInCell(window, cell, output)", self.script)
        self.assertNotIn("lastRegionByWindow", self.script)
        self.assertNotIn("lastCellByWindow", self.script)

    def test_layout_selection_reapplies_active_output_and_managed_apps(self) -> None:
        expected_apps = set(self.apps)
        for layout_name, layout in self.layouts.items():
            with self.subTest(layout=layout_name):
                self.assertEqual(set(layout["apps"]), expected_apps)
                self.assertNotIn("default_region", layout)
                cell_count = len(layout["cells"])
                for app_name, cell in layout["apps"].items():
                    with self.subTest(layout=layout_name, app=app_name):
                        self.assertGreaterEqual(cell, 1)
                        self.assertLessEqual(cell, cell_count)

        for required in [
            "let outputLayouts = {}",
            "if (loaded.output_layouts)",
            "function configuredLayoutNameForOutput(output)",
            "function setLayoutForOutput(output, layoutName)",
            "function clearLayoutForOutput(output)",
            "function outputMatches(window, output)",
            "function outputMatchesName(output, name)",
            "!outputMatches(window, output)",
            "const configured = configuredLayoutNameForOutput(output)",
            "selectLayoutForOutput(output, next);",
            "selectLayoutForOutput(output, selection.slice(7));",
            "reapplyLayout(output);",
            'log("layout " + outputKey(output) + " -> " + layoutName)',
            'log("layout reset for " + outputKey(output))',
            "function handleWindowOutputChanged(window)",
            "window.outputChanged.connect(function ()",
            "placeManagedAppWindowOnOutput(appName, window, targetOutput, false)",
            "steam: 5",
            "steam: 3",
            "handleWindowAvailable(window)",
            "apps[appName] && apps[appName].region",
        ]:
            self.assertIn(required, self.script)
        self.assertNotIn("setLayoutForAllOutputs", self.script)
        self.assertNotIn("clearLayoutForAllOutputs", self.script)
        self.assertNotIn("layout all outputs", self.script)
        self.assertNotIn("defaultPlacedByWindow", self.script)
        self.assertNotIn("function layoutDefaultRegion(layout)", self.script)
        self.assertNotIn("function placeWindowInLayoutDefault(window, layout, output)", self.script)
        self.assertNotIn("placeNewUnmanagedWindow(window)", self.script)
        self.assertNotIn("default_region", self.script)

    def test_layout_reapply_uses_all_kwin_windows_across_desktops(self) -> None:
        for required in [
            "function allWorkspaceWindows()",
            "appendWindows(windows, workspace.windowList(), seen)",
            "const windows = allWorkspaceWindows();",
        ]:
            self.assertIn(required, self.script)




    def test_kwin_script_uses_native_kwin_window_apis(self) -> None:
        for required in [
            "workspace.stackingOrder",
            "workspace.activeWindow",
            "function activateWindowDesktop(window)",
            "workspace.currentDesktop = desktop",
            "workspace.raiseWindow(window)",
            "workspace.clientArea(KWin.PlacementArea, output, desktop)",
            "window.frameGeometry = target",
            "workspace.sendClientToScreen(window, targetOutput)",
            "window.fullScreen = false",
            "window.desktopFileName",
            "window.resourceClass",
            "window.caption",
        ]:
            self.assertIn(required, self.script)

    def test_kwin_script_does_not_use_virtual_work_area_for_regions(self) -> None:
        self.assertNotIn("workspace.clientArea(KWin.WorkArea", self.script)


    def test_kwin_script_uses_dbus_helper_for_config_and_launching(self) -> None:
        for required in [
            'const SUMMON_SERVICE = "io.techdufus.PlasmaSummon"',
            'const SUMMON_PATH = "/io/techdufus/PlasmaSummon"',
            'const SUMMON_INTERFACE = "io.techdufus.PlasmaSummon"',
            'callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "ConfigJson"',
            'callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "LaunchApp", appName',
            '"PickOption"',
        ]:
            self.assertIn(required, self.script)

    def test_plasma_regions_follow_awesomewm_and_hammerspoon_grid_model(self) -> None:
        awesome_positions = AWESOME_POSITIONS.read_text(encoding="utf-8")
        hammerspoon_positions = HAMMERSPOON_POSITIONS.read_text(encoding="utf-8")
        for marker in [
            "'0,0 52x40'",
            "'52,0 28x40'",
            "'50,2 28x20'",
            "'6,5 44x30'",
            "'10,5 60x30'",
            "'48,8 30x24'",
            "'0,0 48x40'",
            "'10,4 60x32'",
        ]:
            self.assertIn(marker, awesome_positions)
            self.assertIn(marker, hammerspoon_positions)

        self.assertEqual(self.apps["terminal"]["region"], "main")
        self.assertIn("name:ghostty", self.apps["terminal"]["match"])
        self.assertIn("desktopFileName:com.mitchellh.ghostty.desktop", self.apps["terminal"]["match"])
        self.assertEqual(self.apps["browser"]["region"], "wide")
        self.assertEqual(self.apps["discord"]["region"], "chat")
        self.assertEqual(self.apps["signal"]["region"], "chat")
        self.assertEqual(self.apps["spotify"]["region"], "side")
        self.assertEqual(self.apps["onepassword"]["region"], "center")
        self.assertEqual(self.apps["files"]["region"], "center")
        self.assertEqual(self.apps["obsidian"]["region"], "side")
        self.assertNotIn("region", self.apps["steam"])
        self.assertEqual(self.regions["main"]["w"], "65%")
        self.assertEqual(self.regions["side"]["x"], "65%")
        self.assertEqual(self.regions["top_right"]["y"], "5%")
        self.assertEqual(self.regions["center_left"]["x"], "7.5%")
        self.assertEqual(self.regions["center"]["w"], "75%")
        self.assertEqual(self.regions["right_small"]["w"], "37.5%")
        self.assertEqual(self.regions["hd_left_main"]["w"], "60%")
        self.assertEqual(self.regions["hd_float_center"]["h"], "80%")
        self.assertEqual(
            self.layouts["fourk"]["cells"],
            ["main", "side", "top_right", "center_left", "center", "right_small"],
        )
        self.assertEqual(
            self.layouts["hd"]["cells"],
            ["hd_left_main", "hd_right_side", "hd_float_center"],
        )
        self.assertEqual(
            self.layouts["standard"]["cells"],
            ["standard_browser_left", "standard_terminal_right", "standard_utility_overlay"],
        )
        self.assertEqual(self.layouts["standard"]["apps"]["browser"], 1)
        self.assertEqual(self.layouts["standard"]["apps"]["terminal"], 2)
        self.assertEqual(self.layouts["standard"]["apps"]["onepassword"], 3)
        self.assertEqual(self.layouts["fourk"]["apps"]["terminal"], 1)
        self.assertEqual(self.layouts["fourk"]["apps"]["browser"], 2)
        self.assertEqual(self.layouts["fourk"]["apps"]["onepassword"], 4)
        self.assertEqual(self.layouts["hd"]["apps"]["onepassword"], 3)
        self.assertEqual(self.regions["standard_browser_left"]["w"], "40%")
        self.assertEqual(self.regions["standard_terminal_right"]["x"], "40%")
        self.assertEqual(self.regions["standard_terminal_right"]["w"], "60%")
        self.assertEqual(self.regions["standard_utility_overlay"]["h"], "80%")

    def test_kwin_embedded_regions_match_edge_aligned_toml_fallback(self) -> None:
        for required in [
            'full: { x: "0%", y: "0%", w: "100%", h: "100%"',
            'hd_left_main: { x: "0%", y: "0%", w: "60%", h: "100%"',
            'hd_right_side: { x: "60%", y: "0%", w: "40%", h: "100%"',
            'cells: ["hd_left_main", "hd_right_side", "hd_float_center"]',
            'standard_terminal_right: { x: "40%", y: "0%", w: "60%", h: "100%"',
            'cells: ["standard_browser_left", "standard_terminal_right", "standard_utility_overlay"]',
        ]:
            self.assertIn(required, self.script)
        for obsolete in [
            'full: { x: "2%", y: "4%", w: "96%", h: "92%"',
            'main: { x: "2%", y: "4%", w: "60%", h: "92%"',
            'side: { x: "64%", y: "4%", w: "34%", h: "92%"',
            'cells: ["main", "side", "center"]',
            "standard_top_left",
            "standard_left_center",
            "standard_bottom_left",
            "standard_center",
            "standard_right",
        ]:
            self.assertNotIn(obsolete, self.script)
        self.assertIn("reapplyAllLayouts();", self.script)
        self.assertIn("function reapplyAllLayouts()", self.script)


    def test_role_is_available_from_default_roles_without_distribution_exclusion(self) -> None:
        all_yml = (REPO_ROOT / "group_vars" / "all.yml").read_text(encoding="utf-8")
        example = (REPO_ROOT / "group_vars" / "all.yml.example").read_text(encoding="utf-8")
        self.assertIn("  - plasma", all_yml)
        self.assertIn("# - plasma", example)
        arch_excludes = all_yml.split("exclude_roles_by_distribution:", maxsplit=1)[1]
        self.assertNotIn("    - plasma", arch_excludes)






class PlasmaSummonServiceTests(unittest.TestCase):
    def test_helper_loads_config_and_serializes_json_for_kwin(self) -> None:
        config = plasma_summon_service.load_config(SUMMON_DIR)
        self.assertEqual(config["apps"]["terminal"]["key"], "t")
        self.assertEqual(config["regions"]["main"]["w"], "65%")
        self.assertEqual(config["layouts"]["fourk"]["apps"]["browser"], 2)
        self.assertNotIn("default_region", config["layouts"]["fourk"])
        self.assertEqual(config["output_layouts"], {})

        payload = json.loads(plasma_summon_service.config_json(SUMMON_DIR))
        self.assertEqual(list(payload["layouts"]), ["fourk", "hd", "standard", "full"])
        self.assertEqual(payload["apps"]["files"]["exec"], "dolphin")
        self.assertEqual(payload["output_layouts"], {})
        self.assertNotIn("default_region", payload["layouts"]["standard"])

    def test_helper_launch_argv_is_whitelisted_by_app_registry(self) -> None:
        apps = plasma_summon_service.load_config(SUMMON_DIR)["apps"]
        self.assertEqual(plasma_summon_service.build_launch_argv(apps, "terminal"), ["ghostty"])
        self.assertEqual(plasma_summon_service.build_launch_argv(apps, "signal"), ["signal-desktop"])
        with self.assertRaises(ValueError):
            plasma_summon_service.build_launch_argv(apps, "missing")

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
        ]:
            self.assertIn(name, obsolete)


if __name__ == "__main__":
    unittest.main()
