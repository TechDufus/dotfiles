#!/usr/bin/env python3
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
TASKS = REPO_ROOT / "roles" / "bun" / "tasks" / "main.yml"


class BunGlobalPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS.read_text(encoding="utf-8")

    def test_global_packages_refresh_every_run(self) -> None:
        self.assertIn("Install or update Bun global packages", self.tasks)
        self.assertIn("bun_global_packages + bun_extra_packages", self.tasks)
        self.assertNotIn("not bun_global_package_dir.stat.exists", self.tasks)
        self.assertIn("package installed", self.tasks)


if __name__ == "__main__":
    unittest.main()
