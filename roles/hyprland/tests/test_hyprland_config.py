#!/usr/bin/env python3
from pathlib import Path
import json
import tomllib
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
CONFIG = REPO_ROOT / "roles" / "hyprland" / "files" / "hypr" / "hyprland.lua"
HYPRIDLE = REPO_ROOT / "roles" / "hyprland" / "files" / "hypr" / "hypridle.conf"
HYPRPAPER = REPO_ROOT / "roles" / "hyprland" / "files" / "hypr" / "hyprpaper.conf"
HYPRLOCK = REPO_ROOT / "roles" / "hyprland" / "files" / "hypr" / "hyprlock.conf"
WAYBAR_CONFIG = REPO_ROOT / "roles" / "hyprland" / "files" / "waybar" / "config.jsonc"
WAYBAR_STYLE = REPO_ROOT / "roles" / "hyprland" / "files" / "waybar" / "style.css"
WAYBAR_PALETTE = REPO_ROOT / "roles" / "hyprland" / "files" / "waybar" / "mocha.css"
WALLPAPER = REPO_ROOT / "roles" / "hyprland" / "files" / "wallpapers" / "catppuccin-mocha.png"
REGIONS = REPO_ROOT / "roles" / "hyprland" / "files" / "summon" / "regions.toml"
LAYOUTS = REPO_ROOT / "roles" / "hyprland" / "files" / "summon" / "layouts.toml"



class HyprlandConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.config = CONFIG.read_text(encoding="utf-8")
        cls.waybar_config = json.loads(WAYBAR_CONFIG.read_text(encoding="utf-8"))
        cls.waybar_style = WAYBAR_STYLE.read_text(encoding="utf-8")
        cls.waybar_palette = WAYBAR_PALETTE.read_text(encoding="utf-8")
        cls.regions = tomllib.loads(REGIONS.read_text(encoding="utf-8"))["regions"]
        cls.layouts = tomllib.loads(LAYOUTS.read_text(encoding="utf-8"))["layouts"]

    def test_dvorak_input_is_managed_in_hyprland(self) -> None:
        for required in [
            'kb_layout  = "us"',
            'kb_variant = "dvorak"',
            'kb_model   = "pc105"',
            'kb_options = "caps:none"',
        ]:
            self.assertIn(required, self.config)


    def test_reload_bind_matches_awesomewm_workflow(self) -> None:
        self.assertIn(
            'hl.bind(mainMod .. " + CONTROL + R", hl.dsp.exec_cmd("hyprctl reload"))',
            self.config,
        )

    def test_catppuccin_compositor_polish_is_managed(self) -> None:
        for required in [
            "Catppuccin Mocha: dark, readable, and maintainable",
            'gaps_out = 10',
            'border_size = 1',
            'rounding       = 15',
            'active_opacity     = 0.97',
            'inactive_opacity   = 0.94',
            'size              = 8',
            'passes            = 2',
            'hl.curve("materialEmphasizedDecel"',
            'hl.animation({ leaf = "specialWorkspace"',
            "disable_hyprland_logo         = true",
            'background_color              = "rgb(11111b)"',
            'name  = "float-file-dialogs"',
            'name  = "pin-picture-in-picture"',
            'name  = "game-performance"',
            'idle_inhibit = "always"',
        ]:
            self.assertIn(required, self.config)

    def test_summon_and_region_submaps_cover_core_workflow(self) -> None:
        for required in [
            'hl.bind("F13",       hl.dsp.submap("summon"))',
            'hl.bind("XF86Tools", hl.dsp.submap("summon"))',
            'hl.bind("Caps_Lock", hl.dsp.submap("summon"))',
            'hl.bind("code:66",   hl.dsp.submap("summon"))',
            'hl.bind("t",      submap_exec(summonCommand .. "terminal"))',
            'hl.bind("b",      submap_exec(summonCommand .. "browser"))',
            'hl.bind("d",      submap_exec(summonCommand .. "discord"))',
            'hl.bind("c",      submap_exec(summonCommand .. "signal"))',
            'hl.bind("s",      submap_exec(summonCommand .. "spotify"))',
            'hl.bind("n",      submap_exec(summonCommand .. "obsidian"))',
            'hl.bind("o",      submap_exec(summonCommand .. "onepassword"))',
            'hl.bind("f",      submap_exec(summonCommand .. "files"))',
            'hl.bind("g",      submap_exec(summonCommand .. "steam"))',
            'hl.bind(mainMod .. " + U", hl.dsp.submap("regions"))',
            'local cellCommand = "hypr-summon cell "',
            'local layoutCycleCommand = "hypr-summon layout cycle"',
            'local layoutResetCommand = "hypr-summon layout reset"',
            'hl.bind(hyper .. " + P",         hl.dsp.exec_cmd(layoutCycleCommand))',
            'hl.bind(hyper .. " + semicolon", hl.dsp.exec_cmd(layoutCycleCommand))',
            'hl.bind(hyper .. " + apostrophe", hl.dsp.exec_cmd(layoutResetCommand))',
            'hl.bind(tostring(i), submap_exec(cellCommand .. i))',
            'hl.bind("m",      submap_exec(regionCommand .. "main"))',
            'hl.bind("w",      submap_exec(regionCommand .. "wide"))',
            'hl.bind("s",      submap_exec(regionCommand .. "side"))',
            'hl.bind("c",      submap_exec(regionCommand .. "chat"))',
            'hl.bind("e",      submap_exec(regionCommand .. "center"))',
            'hl.bind("l",      submap_exec(regionCommand .. "left"))',
            'hl.bind("r",      submap_exec(regionCommand .. "right"))',
            'hl.bind("t",      submap_exec(regionCommand .. "top_right"))',
            'hl.bind("b",      submap_exec(regionCommand .. "bottom_right"))',
            'hl.bind("f",      submap_exec(regionCommand .. "full"))',
            'hl.bind("space",  submap_exec(cycleRegionCommand))',
            'hl.bind("Return", submap_exec(cycleRegionCommand))',
            'hl.bind("F16",         hl.dsp.submap("macro"))',
            'hl.bind("XF86Launch5", hl.dsp.submap("macro"))',
        ]:
            self.assertIn(required, self.config)

    def test_submap_actions_reset_before_dispatching_helpers(self) -> None:
        self.assertIn("local function submap_exec(command)", self.config)
        self.assertIn("hyprctl dispatch 'hl.dsp.submap(\"reset\")'", self.config)

    def test_monitor_movement_binds_cover_multi_monitor_workflow(self) -> None:
        for required in [
            'hl.bind(mainMod .. " + CONTROL + left",  hl.dsp.focus({ monitor = "DP-1" }))',
            'hl.bind(mainMod .. " + CONTROL + right", hl.dsp.focus({ monitor = "HDMI-A-1" }))',
            'hl.bind(mainMod .. " + SHIFT + left",    hl.dsp.window.move({ monitor = "DP-1", follow = true }))',
            'hl.bind(mainMod .. " + SHIFT + right",   hl.dsp.window.move({ monitor = "HDMI-A-1", follow = true }))',
            'hl.bind(mainMod .. " + O",         hl.dsp.exec_cmd(otherMonitorCommand))',
            'hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(previousMonitorCommand))',
        ]:
            self.assertIn(required, self.config)

    def test_role_owns_symlinked_runtime_paths(self) -> None:
        tasks = (REPO_ROOT / "roles" / "hyprland" / "tasks" / "main.yml").read_text(encoding="utf-8")
        for required in [
            "files/hypr/hyprland.lua",
            ".config/hypr/hyprland.lua",
            "files/hypr/hyprlock.conf",
            ".config/hypr/hyprlock.conf",
            "files/hypr/hypridle.conf",
            ".config/hypr/hypridle.conf",
            "files/bin/hypr-summon.py",
            ".local/bin/hypr-summon",
            "files/summon/apps.toml",
            ".config/hypr/summon/apps.toml",
            "files/summon/regions.toml",
            "files/summon/layouts.toml",
            ".config/hypr/summon/layouts.toml",
            ".config/hypr/summon/regions.toml",
            "files/waybar/config.jsonc",
            ".config/waybar/config.jsonc",
            ".config/waybar/config",
            "files/waybar/style.css",
            ".config/waybar/style.css",
            "files/waybar/mocha.css",
            "files/hypr/hyprpaper.conf",
            ".config/hypr/hyprpaper.conf",
            ".config/hypr/wallpapers",
            "files/wallpapers/catppuccin-mocha.png",
            ".config/hypr/wallpapers/catppuccin-mocha.png",
            ".config/waybar/mocha.css",
        ]:
            self.assertIn(required, tasks)

    def test_waybar_normal_top_panel_is_managed(self) -> None:
        modules = (
            self.waybar_config["modules-left"]
            + self.waybar_config["modules-center"]
            + self.waybar_config["modules-right"]
        )

        self.assertEqual(self.waybar_config["position"], "top")
        self.assertNotIn("output", self.waybar_config)
        self.assertEqual(self.waybar_config["height"], 34)
        self.assertTrue(self.waybar_config["exclusive"])
        self.assertEqual(["hyprland/workspaces"], self.waybar_config["modules-left"])
        self.assertEqual(["hyprland/window"], self.waybar_config["modules-center"])
        self.assertIn("tray", self.waybar_config["modules-right"])
        self.assertNotIn("custom/launcher", modules)
        self.assertNotIn("mpd", modules)
        self.assertNotIn("battery", modules)
        self.assertNotIn("cpu", modules)
        self.assertNotIn("memory", modules)
        self.assertEqual(self.waybar_config["pulseaudio"]["format"], "{icon} {volume}%")
        self.assertEqual(self.waybar_config["network"]["format-wifi"], " {essid}")
        self.assertEqual(self.waybar_config["custom/lock"]["format"], "")
        self.assertIn('@import "mocha.css";', self.waybar_style)
        self.assertIn("Normal Catppuccin Mocha top panel", self.waybar_style)
        self.assertIn("background-color: alpha(@base, 0.96)", self.waybar_style)
        self.assertIn("border-bottom: 1px solid @surface0", self.waybar_style)
        self.assertIn("border-bottom-color: @mauve", self.waybar_style)
        self.assertNotIn("linear-gradient(135deg, @mauve, @blue)", self.waybar_style)
        self.assertNotIn("alpha(@base, 0.62)", self.waybar_style)
        self.assertIn("https://github.com/catppuccin/waybar", self.waybar_palette)

    def test_waybar_runtime_uses_managed_config(self) -> None:
        self.assertIn('local waybarCommand = [[waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css"]]', self.config)
        self.assertIn("hl.exec_cmd(waybarCommand)", self.config)
        self.assertNotIn("blur-waybar-glass", self.config)
        self.assertNotIn('match = { namespace = "waybar" }', self.config)

        arch_tasks = (REPO_ROOT / "roles" / "hyprland" / "tasks" / "Archlinux.yml").read_text(encoding="utf-8")
        for package in [
            "ttf-jetbrains-mono-nerd",
            "ttf-nerd-fonts-symbols",
            "otf-font-awesome",
        ]:
            self.assertIn(package, arch_tasks)

    def test_summon_regions_reserve_top_panel_space(self) -> None:
        self.assertEqual(self.regions["full"]["y"], "4%")
        self.assertEqual(self.regions["main"]["w"], "60%")
        self.assertEqual(self.regions["wide"]["w"], "74%")
        self.assertEqual(self.regions["side"]["x"], "64%")
        self.assertEqual(self.regions["chat"]["w"], "36%")
        self.assertEqual(self.regions["center_left"]["w"], "55%")
        self.assertEqual(self.regions["right_small"]["x"], "60%")
        self.assertEqual(self.layouts["fourk"]["cells"][0], "main")
        self.assertEqual(self.layouts["fourk"]["apps"]["terminal"], 1)
        self.assertEqual(self.layouts["fourk"]["apps"]["browser"], 2)
        self.assertEqual(self.layouts["hd"]["max_width"], 2559)
        self.assertEqual(self.layouts["full"]["cells"], ["full"])
        self.assertEqual(
            self.regions["center"],
            {"x": "23%", "y": "15%", "w": "54%", "h": "66%", "float": True},
        )
        self.assertEqual(self.regions["bottom_right"]["y"], "52%")

    def test_catppuccin_wallpaper_is_managed(self) -> None:
        arch_tasks = (REPO_ROOT / "roles" / "hyprland" / "tasks" / "Archlinux.yml").read_text(encoding="utf-8")
        hyprpaper = HYPRPAPER.read_text(encoding="utf-8")

        self.assertIn("hyprpaper", arch_tasks)
        self.assertIn('hl.exec_cmd([[hyprpaper --config "$HOME/.config/hypr/hyprpaper.conf"]])', self.config)
        self.assertIn("splash = false", hyprpaper)
        self.assertIn("path = ~/.config/hypr/wallpapers/catppuccin-mocha.png", hyprpaper)
        self.assertIn("fit_mode = cover", hyprpaper)
        self.assertTrue(WALLPAPER.exists())
        self.assertGreater(WALLPAPER.stat().st_size, 100_000)

    def test_media_keys_are_compositor_locked_for_games(self) -> None:
        for key in [
            "XF86AudioRaiseVolume",
            "XF86AudioLowerVolume",
            "XF86AudioMute",
            "XF86AudioMicMute",
            "XF86MonBrightnessUp",
            "XF86MonBrightnessDown",
            "XF86AudioNext",
            "XF86AudioPause",
            "XF86AudioPlay",
            "XF86AudioPrev",
        ]:
            start = self.config.find(f'hl.bind("{key}"')
            self.assertNotEqual(start, -1, f"missing media binding: {key}")
            end = self.config.find(")\n", start)
            self.assertNotEqual(end, -1, f"malformed media binding: {key}")
            self.assertIn("locked = true", self.config[start:end], key)

    def test_lock_and_idle_stack_is_wired(self) -> None:
        self.assertIn('hl.exec_cmd("hypridle")', self.config)
        self.assertIn('hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("hyprlock"))', self.config)
        self.assertIn("lock_cmd = pidof hyprlock || hyprlock", HYPRIDLE.read_text(encoding="utf-8"))
        self.assertIn("hyprctl dispatch 'hl.dsp.dpms(\"off\")'", HYPRIDLE.read_text(encoding="utf-8"))
        self.assertIn("placeholder_text = Locked", HYPRLOCK.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
