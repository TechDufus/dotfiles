#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ARCH_TASKS = REPO_ROOT / "roles" / "system" / "tasks" / "Archlinux.yml"
GROUP_VARS = REPO_ROOT / "group_vars" / "all.yml"
UDEV_RULE = REPO_ROOT / "roles" / "system" / "files" / "udev" / "rules.d" / "90-disable-logitech-receiver-wakeup.rules"



class ArchKeyboardConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = ARCH_TASKS.read_text(encoding="utf-8")
        cls.group_vars = GROUP_VARS.read_text(encoding="utf-8")
        cls.udev_rule = UDEV_RULE.read_text(encoding="utf-8")

    def test_dvorak_defaults_are_declared(self) -> None:
        for required in [
            "keyboard:",
            "model: pc105",
            "layout: us",
            "variant: dvorak",
            "- caps:none",
        ]:
            self.assertIn(required, self.group_vars)

    def test_arch_system_role_manages_console_and_x11_keymaps(self) -> None:
        for required in [
            "localectl status",
            "set-keymap",
            "set-x11-keymap",
            "arch_console_keymap",
            "arch_x11_options",
            "can_install_packages | default(false)",
        ]:
            self.assertIn(required, self.tasks)

    def test_x11_keymap_guard_checks_exact_current_lines(self) -> None:
        for required in [
            "arch_localectl_status.stdout_lines | default([]) | map('trim') | list",
            "('X11 Layout: ' ~ arch_x11_layout) not in arch_localectl_status_lines",
            "('X11 Model: ' ~ arch_x11_model) not in arch_localectl_status_lines",
            "(arch_x11_variant | length > 0 and ('X11 Variant: ' ~ arch_x11_variant) not in arch_localectl_status_lines)",
            "(arch_x11_options | length > 0 and ('X11 Options: ' ~ arch_x11_options) not in arch_localectl_status_lines)",
        ]:
            self.assertIn(required, self.tasks)

    def test_x11_keymap_guard_clears_stale_empty_fields(self) -> None:
        for required in [
            "(arch_x11_variant | length == 0 and (arch_localectl_status_lines | select('match', '^X11 Variant:') | list | length > 0))",
            "(arch_x11_options | length == 0 and (arch_localectl_status_lines | select('match', '^X11 Options:') | list | length > 0))",
            "set-x11-keymap",
        ]:
            self.assertIn(required, self.tasks)

    def test_localectl_probe_runs_in_check_mode(self) -> None:
        self.assertIn("check_mode: false", self.tasks)
        self.assertIn("Keyboard skipped (localectl unavailable)", self.tasks)

    def test_arch_system_role_disables_logitech_receiver_wakeup(self) -> None:
        for required in [
            "90-disable-logitech-receiver-wakeup.rules",
            "/etc/udev/rules.d",
            "udevadm",
            "settle",
            "--attr-match=idVendor=046d",
            "--attr-match=idProduct=c548",
        ]:
            self.assertIn(required, self.tasks)

        for required in [
            'ACTION=="add"',
            'SUBSYSTEM=="usb"',
            'ENV{DEVTYPE}=="usb_device"',
            'ATTR{idVendor}=="046d"',
            'ATTR{idProduct}=="c548"',
            'ATTR{power/wakeup}="disabled"',
        ]:
            self.assertIn(required, self.udev_rule)


if __name__ == "__main__":
    unittest.main()
