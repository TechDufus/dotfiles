#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import sys
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "files" / "bin" / "hypr-summon.py"
loader = importlib.machinery.SourceFileLoader("hypr_summon", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
hypr_summon = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = hypr_summon
loader.exec_module(hypr_summon)


class SummonMatchingTests(unittest.TestCase):
    def test_matches_class_case_insensitive(self):
        app = {"match": ["class:com.mitchellh.ghostty"]}
        client = {"class": "Com.MitchellH.Ghostty"}
        self.assertTrue(hypr_summon.client_matches(client, app))

    def test_title_match_is_substring_fallback_only(self):
        app = {"match": ["title:Proton"]}
        self.assertTrue(hypr_summon.client_matches({"title": "Steam - Proton Experimental"}, app))
        self.assertFalse(hypr_summon.client_matches({"title": "Steam"}, app))

    def test_best_client_prefers_remembered_address(self):
        clients = [
            {"address": "0x1", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}},
            {"address": "0x2", "class": "ghostty", "monitor": 1, "workspace": {"id": 2}},
        ]
        app = {"match": ["class:ghostty"]}
        active = {"address": "0x3", "class": "brave-browser", "monitor": 0, "workspace": {"id": 1}}
        state = {"last_by_app": {"terminal": "0x2"}}
        self.assertEqual(hypr_summon.best_client(clients, "terminal", app, active, state)["address"], "0x2")

    def test_best_client_prefers_active_monitor_then_workspace(self):
        clients = [
            {"address": "0x1", "class": "ghostty", "monitor": 1, "workspace": {"id": 2}},
            {"address": "0x2", "class": "ghostty", "monitor": 0, "workspace": {"id": 3}},
            {"address": "0x3", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}},
        ]
        app = {"match": ["class:ghostty"]}
        active = {"address": "0x4", "class": "brave-browser", "monitor": 0, "workspace": {"id": 1}}
        state = {"last_by_app": {}}
        self.assertEqual(hypr_summon.best_client(clients, "terminal", app, active, state)["address"], "0x3")

    def test_app_places_existing_client_only_when_explicit(self):
        args = argparse.Namespace(place=False, no_place=False)
        self.assertFalse(hypr_summon.app_places_client({"region": "main"}, args))
        self.assertFalse(hypr_summon.app_places_client({"monitor": "HDMI-A-1"}, args))
        self.assertTrue(hypr_summon.app_places_client({"place": True, "region": "main"}, args))
        self.assertFalse(hypr_summon.app_places_client({}, args))

    def test_lua_dispatchers_target_hyprland_lua_provider(self):
        with patch.object(hypr_summon, "run_hyprctl") as run_hyprctl:
            hypr_summon.dispatch_lua('hl.dsp.focus({ window = "address:0x1" })', dry_run=True)

        run_hyprctl.assert_called_once_with(
            "dispatch",
            'hl.dsp.focus({ window = "address:0x1" })',
            dry_run=True,
        )

    def test_app_place_flags_override_config_default(self):
        self.assertTrue(
            hypr_summon.app_places_client(
                {"place": False},
                argparse.Namespace(place=True, no_place=False),
            )
        )
        self.assertFalse(
            hypr_summon.app_places_client(
                {"region": "main"},
                argparse.Namespace(place=False, no_place=True),
            )
        )

    def test_launched_clients_keep_configured_initial_placement(self):
        args = argparse.Namespace(place=False, no_place=False)
        self.assertTrue(hypr_summon.app_places_launched_client({"region": "main"}, args))
        self.assertTrue(hypr_summon.app_places_launched_client({"monitor": "HDMI-A-1"}, args))
        self.assertFalse(hypr_summon.app_places_launched_client({}, args))


class SummonWorkflowTests(unittest.TestCase):
    def test_summon_app_focuses_existing_window_without_replacing_region(self):
        args = argparse.Namespace(
            config_dir="/unused",
            app="terminal",
            place=False,
            no_place=False,
            dry_run=False,
            force=False,
            launch_timeout=0,
        )
        apps = {"terminal": {"match": ["class:ghostty"], "region": "main"}}
        client = {"address": "0x1", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}}
        active = {"address": "0x2", "class": "brave-browser", "monitor": 0, "workspace": {"id": 2}}
        state = {"last_by_app": {}, "last_region_by_address": {}}

        def fake_hyprctl_json(command: str):
            if command == "clients":
                return [client]
            if command == "activewindow":
                return active
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "app_needs_placement_repair", return_value=False),
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "place_app_client") as place,
            patch.object(hypr_summon, "launch") as launch,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.summon_app(args), 0)

        focus.assert_called_once_with(client, dry_run=False)
        place.assert_not_called()
        launch.assert_not_called()
        save.assert_called_once_with(state)
        self.assertEqual(state["last_by_app"]["terminal"], "0x1")

    def test_same_app_summon_toggles_previous_window_without_explicit_place(self):
        args = argparse.Namespace(
            config_dir="/unused",
            app="terminal",
            place=False,
            no_place=False,
            dry_run=False,
            force=False,
            launch_timeout=0,
        )
        active = {"address": "0x1", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}}
        previous = {"address": "0x2", "class": "brave-browser", "monitor": 0, "workspace": {"id": 1}}
        apps = {"terminal": {"match": ["class:ghostty"], "region": "main"}}
        state = {"previous_address": "0x2", "last_by_app": {}, "last_region_by_address": {}}

        def fake_hyprctl_json(command: str):
            if command == "clients":
                return [active, previous]
            if command == "activewindow":
                return active
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "app_needs_placement_repair", return_value=False),
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "place_app_client") as place,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.summon_app(args), 0)

        focus.assert_called_once_with(previous, dry_run=False)
        place.assert_not_called()
        save.assert_called_once_with(state)
        self.assertEqual(state["last_by_app"]["terminal"], "0x1")

    def test_same_app_summon_ignores_repair_and_toggles_previous_window(self):
        args = argparse.Namespace(
            config_dir="/unused",
            app="terminal",
            place=False,
            no_place=False,
            dry_run=False,
            force=False,
            launch_timeout=0,
        )
        active = {"address": "0x1", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}}
        previous = {"address": "0x2", "class": "brave-browser", "monitor": 0, "workspace": {"id": 1}}
        apps = {"terminal": {"match": ["class:ghostty"], "region": "main"}}
        state = {"previous_address": "0x2", "last_by_app": {}, "last_region_by_address": {}}

        def fake_hyprctl_json(command: str):
            if command == "clients":
                return [active, previous]
            if command == "activewindow":
                return active
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "app_needs_placement_repair", return_value=True),
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "place_app_client") as place,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.summon_app(args), 0)

        focus.assert_called_once_with(previous, dry_run=False)
        place.assert_not_called()
        save.assert_called_once_with(state)
        self.assertEqual(state["last_by_app"]["terminal"], "0x1")

    def test_summon_app_places_active_window_when_placement_is_requested(self):
        args = argparse.Namespace(
            config_dir="/unused",
            app="terminal",
            place=True,
            no_place=False,
            dry_run=False,
            force=False,
            launch_timeout=0,
        )
        active = {"address": "0x1", "class": "ghostty", "monitor": 0, "workspace": {"id": 1}}
        previous = {"address": "0x2", "class": "brave-browser", "monitor": 0, "workspace": {"id": 1}}
        apps = {"terminal": {"match": ["class:ghostty"], "region": "main"}}
        state = {"previous_address": "0x2", "last_by_app": {}, "last_region_by_address": {}}

        def fake_hyprctl_json(command: str):
            if command == "clients":
                return [active, previous]
            if command == "activewindow":
                return active
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "app_needs_placement_repair", return_value=False),
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "place_app_client") as place,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.summon_app(args), 0)

        focus.assert_called_once_with(active, dry_run=False)
        place.assert_called_once()
        save.assert_called_once_with(state)

    def test_place_app_client_moves_to_configured_monitor_before_region(self):
        client = {"address": "0x1", "fullscreen": False, "monitor": 0}
        refreshed = {"address": "0x1", "fullscreen": False, "monitor": 1}
        app = {"monitor": "HDMI-A-1", "region": "main"}

        def fake_hyprctl_json(command: str):
            if command == "activewindow":
                return refreshed
            if command == "monitors":
                return [{"id": 1, "name": "HDMI-A-1", "focused": True, "x": 1920, "y": 0, "width": 3840, "height": 2160}]
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "dispatch_lua") as dispatch_lua,
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "load_regions", return_value={"main": {"x": "0%", "y": "0%", "w": "65%", "h": "100%"}}),
            patch.object(hypr_summon, "apply_region") as apply,
        ):
            hypr_summon.place_app_client("terminal", app, client, Path("/unused"))

        focus.assert_called_once_with(client, dry_run=False)
        dispatch_lua.assert_called_once_with('hl.dsp.window.move({ monitor = 1, window = "address:0x1" })', dry_run=False)
        apply.assert_called_once()
        self.assertIs(apply.call_args.args[1], refreshed)

    def test_move_to_region_refuses_fullscreen_without_force(self):
        args = argparse.Namespace(config_dir="/unused", region="main", force=False, dry_run=False)
        with (
            patch.object(hypr_summon, "load_regions", return_value={"main": {"x": "0%", "y": "0%", "w": "50%", "h": "100%"}}),
            patch.object(hypr_summon, "hyprctl_json", return_value={"address": "0x1", "fullscreen": True}),
        ):
            with self.assertRaisesRegex(SystemExit, "fullscreen"):
                hypr_summon.move_to_region(args)

    def test_cycle_region_advances_state_for_active_window(self):
        args = argparse.Namespace(config_dir="/unused", regions=["main", "wide"], force=False, dry_run=False)
        regions = {
            "main": {"x": "0%", "y": "0%", "w": "65%", "h": "100%"},
            "wide": {"x": "0%", "y": "0%", "w": "80%", "h": "100%"},
        }
        active = {"address": "0x1", "fullscreen": False, "monitor": 0}
        state = {"last_by_app": {}, "last_region_by_address": {"0x1": "main"}}

        def fake_hyprctl_json(command: str):
            if command == "activewindow":
                return active
            if command == "monitors":
                return [{"id": 0, "focused": True, "x": 0, "y": 0, "width": 1000, "height": 800}]
            self.fail(f"unexpected hyprctl command: {command}")

        with (
            patch.object(hypr_summon, "load_regions", return_value=regions),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "hyprctl_json", side_effect=fake_hyprctl_json),
            patch.object(hypr_summon, "apply_region") as apply,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.cycle_region(args), 0)

        apply.assert_called_once()
        save.assert_called_once_with(state)
        self.assertEqual(state["last_region_by_address"]["0x1"], "wide")


    def test_apply_region_uses_lua_window_dispatchers(self):
        client = {"address": "0x1", "monitor": 0}
        monitor = {"id": 0, "focused": True, "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}
        region = {"x": "10%", "y": "5%", "w": "50%", "h": "25%"}

        with patch.object(hypr_summon, "dispatch_lua") as dispatch_lua:
            hypr_summon.apply_region(region, client, [monitor], dry_run=True)

        dispatch_lua.assert_any_call(
            'hl.dsp.window.float({ action = "enable", window = "address:0x1" })',
            dry_run=True,
        )
        dispatch_lua.assert_any_call(
            'hl.dsp.window.resize({ x = 1280, y = 360, relative = false, window = "address:0x1" })',
            dry_run=True,
        )
        dispatch_lua.assert_any_call(
            'hl.dsp.window.move({ x = 2176, y = 72, relative = false, window = "address:0x1" })',
            dry_run=True,
        )

    def test_move_to_cell_persists_known_app_override(self):
        args = argparse.Namespace(config_dir="/unused", cell=2, force=False, dry_run=False)
        apps = {"terminal": {"match": ["class:ghostty"]}}
        regions = {
            "main": {"x": "0%", "y": "0%", "w": "60%", "h": "100%"},
            "side": {"x": "60%", "y": "0%", "w": "40%", "h": "100%"},
        }
        layouts = {"fourk": {"min_width": 2560, "cells": ["main", "side"], "apps": {"terminal": 1}}}
        state = {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }
        active = {"address": "0x1", "class": "ghostty", "fullscreen": False, "monitor": 1}
        monitor = {"id": 1, "name": "HDMI-A-1", "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_regions", return_value=regions),
            patch.object(hypr_summon, "load_layouts", return_value=layouts),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "active_window", return_value=active),
            patch.object(hypr_summon, "active_monitors", return_value=[monitor]),
            patch.object(hypr_summon, "apply_region_on_monitor") as apply,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.move_to_cell(args), 0)

        apply.assert_called_once_with(regions["side"], active, monitor, dry_run=False)
        save.assert_called_once_with(state)
        self.assertEqual(state["app_cell_overrides"]["HDMI-A-1:fourk:terminal"], 2)
        self.assertEqual(state["last_cell_by_address"]["0x1"], 2)

    def test_move_to_other_monitor_uses_target_layout_cell_for_known_app(self):
        args = argparse.Namespace(config_dir="/unused", direction="next", force=False, dry_run=False)
        apps = {"terminal": {"match": ["class:ghostty"], "region": "main"}}
        regions = {
            "main": {"x": "0%", "y": "0%", "w": "60%", "h": "100%"},
            "side": {"x": "60%", "y": "0%", "w": "40%", "h": "100%"},
        }
        layouts = {
            "fourk": {"min_width": 2560, "cells": ["main", "side"], "apps": {"terminal": 2}},
            "hd": {"min_width": 0, "max_width": 2559, "cells": ["main"], "apps": {"terminal": 1}},
        }
        state = {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }
        active = {"address": "0x1", "class": "ghostty", "fullscreen": False, "monitor": 0}
        dp = {"id": 0, "name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1}
        hdmi = {"id": 1, "name": "HDMI-A-1", "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}

        with (
            patch.object(hypr_summon, "load_apps", return_value=apps),
            patch.object(hypr_summon, "load_regions", return_value=regions),
            patch.object(hypr_summon, "load_layouts", return_value=layouts),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "active_window", return_value=active),
            patch.object(hypr_summon, "active_monitors", return_value=[dp, hdmi]),
            patch.object(hypr_summon, "move_window_to_monitor") as move,
            patch.object(hypr_summon, "apply_cell_on_monitor") as apply_cell,
            patch.object(hypr_summon, "apply_relative_geometry_on_monitor") as preserve,
            patch.object(hypr_summon, "dispatch_focus") as focus,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.move_to_other_monitor(args), 0)

        move.assert_called_once_with(active, hdmi, [dp, hdmi], dry_run=False)
        self.assertEqual(apply_cell.call_args.args[2], 2)
        self.assertIs(apply_cell.call_args.args[1], hdmi)
        preserve.assert_not_called()
        focus.assert_called_once_with(active, dry_run=False)
        save.assert_called_once_with(state)

    def test_layout_cycle_stores_layout_for_focused_monitor_and_reapplies(self):
        args = argparse.Namespace(config_dir="/unused", layout_action="cycle", name=None, force=False, dry_run=False)
        monitor = {"id": 1, "name": "HDMI-A-1", "focused": True, "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}
        layouts = {
            "fourk": {"min_width": 2560, "cells": ["main"]},
            "full": {"min_width": 0, "cells": ["full"]},
        }
        state = {
            "last_by_app": {},
            "last_region_by_address": {},
            "last_cell_by_address": {},
            "layout_by_monitor": {},
            "app_cell_overrides": {},
        }

        with (
            patch.object(hypr_summon, "load_apps", return_value={}),
            patch.object(hypr_summon, "load_regions", return_value={}),
            patch.object(hypr_summon, "load_layouts", return_value=layouts),
            patch.object(hypr_summon, "load_state", return_value=state),
            patch.object(hypr_summon, "active_monitors", return_value=[monitor]),
            patch.object(hypr_summon, "reapply_layout_on_monitor") as reapply,
            patch.object(hypr_summon, "save_state") as save,
        ):
            self.assertEqual(hypr_summon.switch_layout(args), 0)

        self.assertEqual(state["layout_by_monitor"]["HDMI-A-1"], "full")
        reapply.assert_called_once()
        save.assert_called_once_with(state)



class RegionGeometryTests(unittest.TestCase):
    def test_region_percentages_use_scaled_monitor_logical_size(self):
        monitor = {"x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}
        region = {"x": "15%", "y": "5%", "w": "70%", "h": "90%"}
        self.assertEqual(hypr_summon.region_geometry(region, monitor), (2304, 72, 1792, 1296))

    def test_region_numeric_dimensions_are_absolute_offsets(self):
        monitor = {"x": 10, "y": 20, "width": 1000, "height": 800}
        region = {"x": 5, "y": 6, "w": 700, "h": 600}
        self.assertEqual(hypr_summon.region_geometry(region, monitor), (15, 26, 700, 600))

    def test_scaled_monitor_bounds_detect_raw_pixel_oversize(self):
        monitor = {"id": 1, "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.5}
        client = {"monitor": 1, "at": [1920, 0], "size": [3072, 2160]}
        self.assertTrue(hypr_summon.client_outside_monitor_bounds(client, [monitor]))

        repaired = {"monitor": 1, "at": [1971, 43], "size": [1587, 1325]}
        self.assertFalse(hypr_summon.client_outside_monitor_bounds(repaired, [monitor]))


if __name__ == "__main__":
    unittest.main()
