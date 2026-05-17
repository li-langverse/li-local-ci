#!/usr/bin/env python3
"""Discover .github/workflows/*.yml and pick act events for local CI."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Skip noisy / non-CI workflows unless explicitly configured
SKIP_NAME_RE = re.compile(
    r"(release|notify|upstream|dependabot|pages|deploy|benchmarks-nightly)",
    re.I,
)
EVENT_PRIORITY = ("pull_request", "workflow_dispatch", "push")


def _load_yaml_on(path: Path) -> dict | list | str | None:
    try:
        import yaml  # type: ignore
    except ImportError:
        return _parse_on_regex(path.read_text(encoding="utf-8", errors="replace"))
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return _parse_on_regex(path.read_text(encoding="utf-8", errors="replace"))
    if not isinstance(data, dict):
        return None
    return data.get("on") or data.get(True)  # yaml 1.1 'on' key


def _parse_on_regex(text: str) -> dict | None:
    """Minimal fallback when PyYAML is missing."""
    m = re.search(r"(?m)^on:\s*$", text)
    if not m:
        return None
    block = text[m.end() : m.end() + 800]
    events: dict[str, object] = {}
    for ev in EVENT_PRIORITY:
        if re.search(rf"(?m)^\s*{ev}\s*:", block) or re.search(rf"(?m)^\s*-\s*{ev}\s*$", block):
            events[ev] = {}
    if re.search(r"(?m)^\s*\[", block):
        for ev in re.findall(r"[\w_]+", block.split("\n", 1)[0]):
            if ev in EVENT_PRIORITY:
                events[ev] = {}
    return events or None


def events_from_on(on: object) -> list[str]:
    if on is None:
        return []
    if isinstance(on, str):
        return [on]
    if isinstance(on, list):
        return [str(x) for x in on]
    if isinstance(on, dict):
        return list(on.keys())
    return []


def pick_event(events: list[str]) -> str | None:
    for ev in EVENT_PRIORITY:
        if ev in events:
            return ev
    return events[0] if events else None


def discover_repo(repo_path: Path, repo_name: str, config_path: Path) -> list[dict]:
    configured: list[dict] = []
    if config_path.is_file():
        try:
            cfg = json.loads(config_path.read_text(encoding="utf-8"))
            entry = cfg.get(repo_name)
            if isinstance(entry, dict) and entry.get("workflows"):
                for w in entry["workflows"]:
                    configured.append(
                        {
                            "file": w["file"],
                            "event": w["event"],
                            "source": "config",
                        }
                    )
                return configured
        except (OSError, json.JSONDecodeError):
            pass

    wf_dir = repo_path / ".github" / "workflows"
    if not wf_dir.is_dir():
        return []

    found: list[dict] = []
    for yml in sorted(wf_dir.glob("*.yml")) + sorted(wf_dir.glob("*.yaml")):
        if SKIP_NAME_RE.search(yml.stem):
            continue
        on = _load_yaml_on(yml)
        events = events_from_on(on)
        ev = pick_event(events)
        if not ev:
            continue
        rel = str(yml.relative_to(repo_path))
        found.append({"file": rel, "event": ev, "source": "discover", "events": events})

    # Prefer ci.yml / ci.yaml when multiple
    found.sort(key=lambda r: (0 if Path(r["file"]).name.startswith("ci.") else 1, r["file"]))
    if not found:
        return []
    # Default: primary CI workflow only (avoid running entire org workflow surface)
    primary = found[0]
    return [{"file": primary["file"], "event": primary["event"], "source": primary["source"]}]


def main() -> int:
    p = argparse.ArgumentParser(description="Discover workflows for act")
    p.add_argument("repo_path", type=Path)
    p.add_argument("--repo-name", default="")
    p.add_argument("--config", type=Path, default=None)
    p.add_argument("--all-pr", action="store_true", help="every workflow with pull_request")
    args = p.parse_args()
    repo_path = args.repo_path.resolve()
    name = args.repo_name or repo_path.name
    config = args.config or Path(__file__).resolve().parents[1] / "config" / "repo-workflows.json"

    if args.all_pr:
        wf_dir = repo_path / ".github" / "workflows"
        out = []
        for yml in sorted(wf_dir.glob("*.yml")) + sorted(wf_dir.glob("*.yaml")):
            if SKIP_NAME_RE.search(yml.stem):
                continue
            on = _load_yaml_on(yml)
            events = events_from_on(on)
            if "pull_request" not in events:
                continue
            out.append(
                {
                    "file": str(yml.relative_to(repo_path)),
                    "event": "pull_request",
                    "source": "discover-all-pr",
                }
            )
        print(json.dumps(out, indent=2))
        return 0

    print(json.dumps(discover_repo(repo_path, name, config), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
