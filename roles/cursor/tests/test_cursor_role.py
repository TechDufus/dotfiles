#!/usr/bin/env python3
from pathlib import Path
import json
import re
import subprocess
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]
ROLE_ROOT = REPO_ROOT / "roles" / "cursor"
TASKS_PATH = ROLE_ROOT / "tasks" / "main.yml"
DEFAULTS_PATH = ROLE_ROOT / "defaults" / "main.yml"
AGENTS_DIR = ROLE_ROOT / "files" / "agents"
RULES_DIR = ROLE_ROOT / "files" / "rules"
SKILLS_DIR = ROLE_ROOT / "files" / "skills"
EXPECTED_RULES = {
    "delegation",
    "interaction",
    "user",
}
GROUP_VARS_ROOT = REPO_ROOT / "group_vars"
RESERVED_AGENT_NAMES = {"explore", "bash", "browser"}
EXPECTED_AGENTS = {
    "gap-advisor",
    "plan-critic",
    "risk-assessor",
    "security-auditor",
    "validator",
}
EXPECTED_SKILLS = {
    "commit",
    "orchestrate",
    "ultraresearch",
    "ultrathink",
    "verification",
}
SLASH_ONLY_SKILLS = {
    "orchestrate",
    "ultraresearch",
    "ultrathink",
}


def load_task_blocks(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    starts = [match.start() for match in re.finditer(r"(?m)^- name:", text)]
    return [
        text[start:end].rstrip()
        for start, end in zip(starts, starts[1:] + [len(text)])
    ]


def parse_top_level_list(text: str, key: str) -> list[str]:
    lines = text.splitlines()
    try:
        start = lines.index(f"{key}:") + 1
    except ValueError as error:
        raise AssertionError(f"missing top-level list {key}") from error

    values = []
    for line in lines[start:]:
        if line and not line[0].isspace():
            break
        match = re.match(r"^\s+-\s+([^#\s]+)", line)
        if match:
            values.append(match.group(1))
    return values


def parse_frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise AssertionError(f"{path} must start with YAML frontmatter")
    try:
        closing_index = lines.index("---", 1)
    except ValueError as error:
        raise AssertionError(f"{path} frontmatter must close") from error

    metadata: dict[str, str] = {}
    for line in lines[1:closing_index]:
        if not line.strip():
            continue
        key, separator, raw_value = line.partition(":")
        if not separator:
            raise AssertionError(f"{path} has invalid frontmatter line: {line}")
        metadata[key.strip()] = raw_value.strip()
    return metadata


class CursorRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tasks = TASKS_PATH.read_text(encoding="utf-8")
        cls.task_blocks = load_task_blocks(TASKS_PATH)
        cls.defaults = DEFAULTS_PATH.read_text(encoding="utf-8")
        cls.managed_cli_config = json.loads(
            (ROLE_ROOT / "files" / "cli-config.json").read_text(encoding="utf-8")
        )
        cls.current_group_vars_text = (GROUP_VARS_ROOT / "all.yml").read_text(
            encoding="utf-8"
        )
        cls.example_group_vars_text = (GROUP_VARS_ROOT / "all.yml.example").read_text(
            encoding="utf-8"
        )
        cls.readme = (ROLE_ROOT / "README.md").read_text(encoding="utf-8")

    def _task_with_action(self, action: str, *, expected: int = 1) -> str:
        action_line = re.compile(rf"(?m)^  {re.escape(action)}:")
        matches = [task for task in self.task_blocks if action_line.search(task)]
        self.assertEqual(len(matches), expected, f"expected {expected} task using {action}")
        return matches[0]

    def test_installs_official_agent_cli_only_when_missing(self) -> None:
        install = [
            task
            for task in self.task_blocks
            if "Install Cursor Agent CLI" in task
        ]
        self.assertEqual(len(install), 1)
        download = [
            task
            for task in self.task_blocks
            if "Download Cursor Agent CLI installer" in task
        ]
        self.assertEqual(len(download), 1)
        self.assertIn("ansible.builtin.get_url:", download[0])
        self.assertIn("cursor_install_url", download[0])
        self.assertIn("cursor_effective_agent_bin | length == 0", download[0])
        self.assertIn("creates: \"{{ cursor_agent_bin }}\"", install[0])
        self.assertIn("ansible.builtin.command:", install[0])
        self.assertIn("cursor_effective_agent_bin | length == 0", install[0])
        self.assertIn("not ansible_check_mode", install[0])
        self.assertNotIn("homebrew_cask", self.tasks)

    def test_cli_config_is_merged_regular_file_with_secret_redaction(self) -> None:
        refuse_symlink = [
            task for task in self.task_blocks if "Refuse symlinked Cursor CLI config" in task
        ]
        merge = [
            task for task in self.task_blocks if "Merge managed Cursor CLI config" in task
        ]
        deploy = [
            task for task in self.task_blocks if "Deploy Cursor CLI config" in task
        ]
        slurp = [
            task for task in self.task_blocks if "Read existing Cursor CLI config" in task
        ]
        self.assertEqual(len(refuse_symlink), 1)
        self.assertEqual(len(merge), 1)
        self.assertEqual(len(deploy), 1)
        self.assertEqual(len(slurp), 1)
        self.assertIn("combine(cursor_managed_cli_config, recursive=true)", merge[0])
        self.assertIn("no_log: true", slurp[0])
        self.assertIn("no_log: true", merge[0])
        self.assertIn("no_log: true", deploy[0])
        self.assertIn('mode: "0600"', deploy[0])
        self.assertIn(
            "cursor_existing_cli_config_canonical != cursor_merged_cli_config_canonical",
            deploy[0],
        )
        self.assertNotIn("authInfo", json.dumps(self.managed_cli_config))
        self.assertNotIn("privacyCache", json.dumps(self.managed_cli_config))
        self.assertEqual(self.managed_cli_config["approvalMode"], "unrestricted")
        self.assertEqual(self.managed_cli_config["sandbox"]["mode"], "disabled")
        self.assertEqual(self.managed_cli_config["selectedModel"]["modelId"], "grok-4.6")
        self.assertEqual(
            self.managed_cli_config["model"]["displayName"],
            "Cursor Grok 4.6 Extra High",
        )
        self.assertEqual(
            self.managed_cli_config["permissions"]["allow"],
            ["Shell(**)", "Read(**)", "Write(**)", "WebFetch(*)", "Mcp(*:*)"],
        )
        self.assertNotIn("Grep(**)", self.managed_cli_config["permissions"]["allow"])
        self.assertFalse(self.managed_cli_config["attribution"]["attributeCommitsToAgent"])
        self.assertEqual(self.managed_cli_config["statusLine"]["type"], "command")
        self.assertEqual(
            self.managed_cli_config["statusLine"]["command"],
            "~/.cursor/statusline.sh",
        )
        self.assertIn(
            "cursor_managed_cli_config.model)",
            merge[0],
        )
        self.assertIn(
            "'statusLine': cursor_managed_cli_config.statusLine",
            merge[0],
        )

    def test_agents_are_omp_specialists_with_cursor_frontmatter(self) -> None:
        agent_files = sorted(AGENTS_DIR.glob("*.md"))
        names = {path.stem for path in agent_files}
        self.assertEqual(names, EXPECTED_AGENTS)
        self.assertTrue(names.isdisjoint(RESERVED_AGENT_NAMES))
        for path in agent_files:
            metadata = parse_frontmatter(path)
            self.assertEqual(metadata["name"], path.stem)
            self.assertEqual(metadata["model"], "composer-2.5")
            self.assertEqual(metadata["readonly"], "true")
            self.assertIn("proactively", metadata["description"].lower())
            self.assertNotIn("tools", metadata)
            self.assertNotIn("@task", path.read_text(encoding="utf-8"))

    def test_always_on_rules_carry_user_workstyle(self) -> None:
        rule_files = sorted(RULES_DIR.glob("*.mdc"))
        names = {path.stem for path in rule_files}
        self.assertEqual(names, EXPECTED_RULES)
        for path in rule_files:
            metadata = parse_frontmatter(path)
            self.assertEqual(metadata["alwaysApply"], "true")
        interaction = (RULES_DIR / "interaction.mdc").read_text(encoding="utf-8")
        delegation = (RULES_DIR / "delegation.mdc").read_text(encoding="utf-8")
        user_rule = (RULES_DIR / "user.mdc").read_text(encoding="utf-8")
        self.assertIn("Lead with the answer or outcome.", interaction)
        self.assertIn("For reviews, lead with material findings", interaction)
        self.assertIn("decomposes, dispatches, integrates, and judges", delegation)
        self.assertIn("After subagent results", delegation)
        self.assertIn("Task subagents", delegation)
        self.assertNotIn("generalPurpose", delegation)
        self.assertNotIn("explore", delegation.lower())
        self.assertNotIn("orchestrate", interaction.lower())
        self.assertNotIn("orchestrate", delegation.lower())
        self.assertNotIn("Lead with the answer", user_rule)
        self.assertIn("cursor_agents_md_dest", self.defaults)
        self.assertNotIn("cursor_agents_md_source", self.defaults)
        self.assertIn("Remove retired user-level AGENTS.md symlink", self.tasks)
        self.assertIn("rules/interaction.mdc", self.readme)
        self.assertIn("rules/delegation.mdc", self.readme)
        self.assertIn("Cursor does not load `~/.cursor/AGENTS.md`", self.readme)

    def test_skills_are_per_directory_and_ignore_builtin_cache(self) -> None:
        skill_names = {path.name for path in SKILLS_DIR.iterdir() if path.is_dir()}
        self.assertEqual(skill_names, EXPECTED_SKILLS)
        for skill in skill_names:
            self.assertTrue((SKILLS_DIR / skill / "SKILL.md").is_file())
            metadata = parse_frontmatter(SKILLS_DIR / skill / "SKILL.md")
            self.assertEqual(metadata["name"], skill)
            self.assertTrue(metadata["description"])
        for skill in SLASH_ONLY_SKILLS:
            metadata = parse_frontmatter(SKILLS_DIR / skill / "SKILL.md")
            self.assertEqual(metadata["disable-model-invocation"], "true")
        orchestrate_meta = parse_frontmatter(SKILLS_DIR / "orchestrate" / "SKILL.md")
        self.assertEqual(orchestrate_meta["disable-model-invocation"], "true")
        self.assertIn("Maximum-effort", orchestrate_meta["description"])
        self.assertIn("Use only when the user invokes /orchestrate", orchestrate_meta["description"])
        orchestrate = (SKILLS_DIR / "orchestrate" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("generalPurpose", orchestrate)
        self.assertIn("explore", orchestrate)
        self.assertIn("Do not Task-spawn them", orchestrate)
        self.assertIn("optional", orchestrate)
        self.assertIn("validator", orchestrate)
        self.assertIn("StrReplace", orchestrate)
        self.assertIn("TodoWrite", orchestrate)
        self.assertIn("Do not wait for the user to ask", orchestrate)
        self.assertNotIn("`sonic`", orchestrate)
        self.assertNotIn("`scout`", orchestrate)
        self.assertNotIn("`librarian`", orchestrate)
        self.assertNotIn("`oracle`", orchestrate)
        self.assertNotIn("bun check", orchestrate)
        ultrathink = (SKILLS_DIR / "ultrathink" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("first-principles", ultrathink.lower())
        self.assertIn("/orchestrate", ultrathink)
        auditor = parse_frontmatter(AGENTS_DIR / "security-auditor.md")
        self.assertIn("security-review", auditor["description"])
        self.assertFalse((ROLE_ROOT / "files" / "AGENTS.md").exists())
        self.assertIn("`orchestrate`", self.readme)
        self.assertIn("cursor_skills_dest", self.defaults)
        self.assertNotIn("skills-cursor", self.tasks)
        self.assertIn("never manage `~/.cursor/skills-cursor/`", self.readme.lower())
        statusline = ROLE_ROOT / "files" / "statusline.sh"
        self.assertTrue(statusline.is_file())
        self.assertTrue(statusline.stat().st_mode & 0o111)
        self.assertIn("cursor_statusline_dest", self.defaults)
        self.assertIn("statusline.sh", self.readme.lower())

    def test_statusline_renders_cursor_payload(self) -> None:
        script = ROLE_ROOT / "files" / "statusline.sh"
        payload = {
            "session_name": "auth-fix",
            "cwd": str(REPO_ROOT),
            "autorun": True,
            "model": {
                "id": "grok-4.6",
                "display_name": "Cursor Grok 4.6 Extra High",
                "param_summary": "Extra High",
                "max_mode": False,
            },
            "workspace": {
                "current_dir": str(REPO_ROOT),
                "project_dir": str(REPO_ROOT),
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
            [str(script)],
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
        self.assertIn(str(REPO_ROOT).replace(str(Path.home()), "~"), result.stdout)

        payload["model"]["display_name"] = "Claude 4 Opus"
        payload["model"]["param_summary"] = "(Thinking)"
        thinking = subprocess.run(
            [str(script)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(thinking.returncode, 0, thinking.stderr)
        self.assertIn("Claude 4 Opus", thinking.stdout)
        self.assertIn("(Thinking)", thinking.stdout)

    def test_readme_stays_omp_aligned_and_cursor_specific(self) -> None:
        self.assertIn("`roles/omp`", self.readme)
        self.assertIn("omp-cursor", self.readme)
        self.assertNotIn("workflow-router", self.readme)
        self.assertNotIn("claude.ai/install.sh", self.tasks)

    def test_current_profile_enables_cursor_after_omp_and_example_keeps_it_opt_in(self) -> None:
        roles = parse_top_level_list(self.current_group_vars_text, "default_roles")
        self.assertIn("cursor", roles)
        self.assertIn("omp", roles)
        self.assertLess(roles.index("omp"), roles.index("cursor"))
        self.assertRegex(
            self.example_group_vars_text,
            re.compile(
                r"^\s*#\s*-\s+cursor\s+#\s+Cursor Agent CLI and user-level agent config\s*$",
                re.MULTILINE,
            ),
        )


if __name__ == "__main__":
    unittest.main()
