#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import unittest


MODULE_ROOT = Path(__file__).resolve().parents[1]
STATUSLINE = MODULE_ROOT / "statusline.sh"


class StatuslineTests(unittest.TestCase):
    def test_statusline_renders_cursor_payload(self) -> None:
        payload = {
            "session_name": "auth-fix",
            "cwd": str(MODULE_ROOT),
            "autorun": True,
            "model": {
                "id": "grok-4.6",
                "display_name": "Cursor Grok 4.6 Extra High",
                "param_summary": "Extra High",
                "max_mode": False,
            },
            "workspace": {
                "current_dir": str(MODULE_ROOT),
                "project_dir": str(MODULE_ROOT),
            },
            "version": "2026.08.25-test",
            "output_style": {"name": "compact"},
            "context_window": {
                "total_input_tokens": 15234,
                "total_output_tokens": 1200,
                "context_window_size": 200000,
                "used_percentage": 34.5,
                "remaining_percentage": 65.5,
            },
            "worktree": {"name": "auth-fix", "path": "/tmp/auth-fix"},
            "render_width_chars": 120,
        }
        result = subprocess.run(
            [str(STATUSLINE)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Cursor Grok 4.6 Extra High", result.stdout)
        self.assertEqual(result.stdout.count("Extra High"), 1)
        self.assertNotIn("2026.08.25-test", result.stdout)
        self.assertIn("YOLO", result.stdout)
        self.assertIn("compact", result.stdout)
        self.assertIn("34%", result.stdout)
        self.assertIn("wt auth-fix", result.stdout)
        self.assertIn(str(MODULE_ROOT).replace(str(Path.home()), "~"), result.stdout)

        payload["model"]["display_name"] = "Claude 4 Opus"
        payload["model"]["param_summary"] = "(Thinking)"
        thinking = subprocess.run(
            [str(STATUSLINE)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(thinking.returncode, 0, thinking.stderr)
        self.assertIn("Claude 4 Opus", thinking.stdout)
        self.assertIn("(Thinking)", thinking.stdout)


if __name__ == "__main__":
    unittest.main()
