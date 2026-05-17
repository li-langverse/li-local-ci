#!/usr/bin/env python3
"""Write or merge one row into local-ci-results.json (always, pass or fail)."""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Usage: write-result.py <row.json> [--merge path/to/local-ci-results.json]",
            file=sys.stderr,
        )
        return 2
    row_path = Path(sys.argv[1])
    row = json.loads(row_path.read_text(encoding="utf-8"))
    merge_path: Path | None = None
    if "--merge" in sys.argv:
        merge_path = Path(sys.argv[sys.argv.index("--merge") + 1])
    print(json.dumps(row, indent=2))
    if merge_path:
        merge_path.parent.mkdir(parents=True, exist_ok=True)
        data: dict = {"runs": [], "generated_at": ""}
        if merge_path.is_file():
            try:
                data = json.loads(merge_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                pass
        runs = {r.get("key"): r for r in data.get("runs", [])}
        runs[row["key"]] = row
        data["runs"] = list(runs.values())
        data["generated_at"] = row.get("finished_at") or datetime.now(timezone.utc).strftime(
            "%Y-%m-%dT%H:%MZ"
        )
        merge_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
