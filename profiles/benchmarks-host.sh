# benchmarks: fast validation (no full ecosystem audit)
test -f scripts/agent-briefing.py
test -f scripts/pr-merge-gate.py
test -f scripts/local-ci-sweep.py
python3 -c "import json; from pathlib import Path; p=Path('data/latest/agent-briefing.json'); assert p.is_file(), 'run agent-briefing first'; json.loads(p.read_text())"
