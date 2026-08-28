#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS = REPO_ROOT / "roles" / "terraform" / "tasks" / "MacOSX.yml"


class TerraformMacOSXTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS.read_text(encoding="utf-8")

    def test_installs_terraform_from_hashicorp_tap(self) -> None:
        self.assertIn("hashicorp/tap", self.tasks)
        self.assertIn("hashicorp/tap/terraform", self.tasks)
        self.assertNotIn("\n    - terraform\n", self.tasks)


if __name__ == "__main__":
    unittest.main()
