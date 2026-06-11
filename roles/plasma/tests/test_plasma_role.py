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
HYPR_SUMMON_DIR = REPO_ROOT / "roles" / "hyprland" / "files" / "summon"

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
            'const triggerPrefixes = ["F13", "CapsLock"]',
            'prefix + "," + key',
            'registerShortcut("Move Active to Region " + regionName',
            '"Meta+U," + key',
            'registerShortcut("Move Active to Cell " + cell',
            '"Meta+U," + cell',
            'registerShortcut("Move Active Window to Next Screen"',
            '"Meta+O"',
            'registerShortcut("Move Active Window to Previous Screen"',
            '"Meta+Shift+O"',
            'registerShortcut("Cycle Active Screen Layout"',
            '"Meta+Alt+Ctrl+Shift+P"',
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
        ]:
            self.assertNotIn(invalid, self.script)
        self.assertNotIn("Tools", self.script)



    def test_kwin_script_uses_native_kwin_window_apis(self) -> None:
        for required in [
            "workspace.stackingOrder",
            "workspace.activeWindow",
            "workspace.raiseWindow(window)",
            "workspace.clientArea(KWin.WorkArea, output, desktop)",
            "window.frameGeometry = target",
            "workspace.sendClientToScreen(window, targetOutput)",
            "window.fullScreen",
            "refusing to move fullscreen window",
            "window.desktopFileName",
            "window.resourceClass",
            "window.caption",
        ]:
            self.assertIn(required, self.script)

    def test_kwin_script_uses_dbus_helper_for_config_and_launching(self) -> None:
        for required in [
            'const SUMMON_SERVICE = "io.techdufus.PlasmaSummon"',
            'const SUMMON_PATH = "/io/techdufus/PlasmaSummon"',
            'const SUMMON_INTERFACE = "io.techdufus.PlasmaSummon"',
            'callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "ConfigJson"',
            'callDBus(SUMMON_SERVICE, SUMMON_PATH, SUMMON_INTERFACE, "LaunchApp", appName',
        ]:
            self.assertIn(required, self.script)

    def test_plasma_registries_preserve_hyprland_workflow_model(self) -> None:
        hypr_apps = load_toml(HYPR_SUMMON_DIR / "apps.toml")["apps"]
        hypr_regions = load_toml(HYPR_SUMMON_DIR / "regions.toml")["regions"]
        hypr_layouts = load_toml(HYPR_SUMMON_DIR / "layouts.toml")["layouts"]

        self.assertEqual(set(hypr_apps), set(self.apps))
        self.assertEqual(
            {name: config["key"] for name, config in hypr_apps.items()},
            {name: config["key"] for name, config in self.apps.items()},
        )
        self.assertEqual(hypr_regions, self.regions)
        self.assertEqual(
            {name: config["cells"] for name, config in hypr_layouts.items()},
            {name: config["cells"] for name, config in self.layouts.items()},
        )
        self.assertEqual(
            {name: config["apps"] for name, config in hypr_layouts.items()},
            {name: config["apps"] for name, config in self.layouts.items()},
        )

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
        self.assertEqual(config["regions"]["main"]["w"], "60%")
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


if __name__ == "__main__":
    unittest.main()
