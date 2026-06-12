#!/usr/bin/env python3
from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import sys
import tomllib
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE = REPO_ROOT / "roles" / "plasma"
HELPER = ROLE / "files" / "bin" / "plasma-summon-service.py"
KWIN_SCRIPT = ROLE / "files" / "kwin" / "plasma-summon" / "contents" / "code" / "main.js"
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


class PlasmaRoleConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = (ROLE / "tasks" / "main.yml").read_text(encoding="utf-8")
        cls.arch_tasks = (ROLE / "tasks" / "Archlinux.yml").read_text(encoding="utf-8")
        cls.defaults = (ROLE / "defaults" / "main.yml").read_text(encoding="utf-8")
        cls.script = KWIN_SCRIPT.read_text(encoding="utf-8")
        cls.metadata = json.loads(KWIN_METADATA.read_text(encoding="utf-8"))
        cls.service = (ROLE / "files" / "systemd" / "plasma-summon.service").read_text(encoding="utf-8")
        cls.apps = load_toml(SUMMON_DIR / "apps.toml")["apps"]
        cls.regions = load_toml(SUMMON_DIR / "regions.toml")["regions"]
        cls.layouts = load_toml(SUMMON_DIR / "layouts.toml")["layouts"]

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
        ]:
            self.assertIn(package, self.defaults)
        self.assertIn("community.general.pacman", self.arch_tasks)
        self.assertIn("can_install_packages | default(false)", self.arch_tasks)
        self.assertIn("Enable SDDM display manager", self.arch_tasks)

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
            "Meta+U,none,Pick region/cell for active window",
            "Pick Active Screen Layout",
            "Meta+Ctrl+Alt+Shift+P,none,Pick active screen layout",
            "Ask KGlobalAccel to release System Settings Tools shortcut",
            "/component/systemsettings_desktop",
            "Load Plasma summon into running KWin",
            "org.kde.kwin.Scripting.loadScript",
            "{{ plasma_kwin_scripts_dir }}/{{ plasma_summon_script_id }}/contents/code/main.js",
            "Start pending KWin scripts",
            "org.kde.kwin.Scripting.start",
            "Configure running Plasma summon shortcuts",
            "--configure-shortcuts",
            "kwriteconfig6",
            "qdbus6",
        ]:
            self.assertIn(required, self.tasks)
        self.assertIn("plasma_summon_script_id: plasma-summon", self.defaults)
        self.assertIn("ExecStart=%h/.local/bin/plasma-summon-service", self.service)
        self.assertIn("WantedBy=default.target", self.service)

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
            'registerShortcut("Pick Active Window Region"',
            '"Meta+U", showCellPicker',
            'requestPicker("Move " + appName',
            '"PickOption"',
            'registerShortcut("Move Active Window to Next Screen"',
            '"Meta+O"',
            'registerShortcut("Move Active Window to Previous Screen"',
            '"Meta+Shift+O"',
            'registerShortcut("Pick Active Screen Layout"',
            '"Meta+Alt+Ctrl+Shift+P", showLayoutPicker',
            '"Meta+Alt+Ctrl+Shift+;"',
            "\"Meta+Alt+Ctrl+Shift+'\"",
            'registerShortcut("Reload Plasma Summon Configuration Hyper"',
            '"Meta+Alt+Ctrl+Shift+R"',
        ]:
            self.assertIn(required, self.script)
        for invalid in [
            "XF86Tools",
            "Meta+Alt+Ctrl+Shift+Semicolon",
            "Meta+Alt+Ctrl+Shift+Apostrophe",
            'registerShortcut("Move Active to Region " + regionName',
            '"Meta+U," + key',
            'registerShortcut("Move Active to Cell " + cell',
            '"Meta+U," + cell',
        ]:
            self.assertNotIn(invalid, self.script)

    def test_kwin_script_places_newly_launched_apps_with_current_layout_cells(self) -> None:
        for required in [
            "pendingLaunches",
            "function outputByName(name)",
            "function targetOutputForApp(appConfig, fallback)",
            "function placeAppWindow(appName, window)",
            "configuredAppCell(targetOutput, pair[0], pair[1], appName)",
            "placeWindowInLayoutCell(window, cell, targetOutput, false)",
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
            "window.fullScreen",
            "refusing to move fullscreen window",
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

        self.assertNotIn("region", self.apps["terminal"])
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
        self.assertEqual(self.layouts["fourk"]["apps"]["terminal"], 1)
        self.assertEqual(self.layouts["fourk"]["apps"]["browser"], 2)
        self.assertEqual(self.layouts["fourk"]["apps"]["onepassword"], 4)
        self.assertEqual(self.layouts["hd"]["apps"]["onepassword"], 3)

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

        payload = json.loads(plasma_summon_service.config_json(SUMMON_DIR))
        self.assertEqual(payload["apps"]["files"]["exec"], "dolphin")

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

    def test_helper_builds_safe_picker_arguments(self) -> None:
        options = plasma_summon_service.parse_picker_options(
            '[{"id":"cell:1","label":"1  main (terminal)"},{"id":"cell:2","label":"2  side (browser)"}]'
        )
        self.assertEqual(options[0]["id"], "cell:1")
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

    def test_helper_defines_runtime_picker_shortcuts(self) -> None:
        shortcuts = plasma_summon_service.summon_shortcuts()
        self.assertEqual(
            shortcuts,
            [
                (
                    ["kwin", "Pick Active Window Region", "KWin", "Pick region/cell for active window"],
                    [0x10000000 + ord("U")],
                ),
                (
                    ["kwin", "Pick Active Screen Layout", "KWin", "Pick active screen layout"],
                    [0x1E000000 + ord("P")],
                ),
            ],
        )


if __name__ == "__main__":
    unittest.main()
