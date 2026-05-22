---
name: run-local-ci-gha-quota
description: >-
  Run Li ecosystem CI locally when GitHub Actions minutes are exhausted. Primary
  entry for this repo — li-local-ci bin, act, profiles, merge-gate JSON. Use for
  GHA quota, local-ci-sweep, run-pr, or before merging any li-langverse PR.
---

# Run local CI (li-local-ci)

This repository is the **canonical implementation** for local GitHub Actions parity. Agents and humans use it when **GHA minutes are exhausted** or checks are missing.

## Install

```bash
brew install act    # optional; host profiles work without it
./bin/li-local-ci doctor
```

Sibling layout:

```text
li-langverse/
  li-local-ci/    # this repo
  lic/
  benchmarks/     # local-ci-sweep.py + pr-merge-gate.py
```

## Commands

```bash
./bin/li-local-ci run-pr --repo lic --pr N
./bin/li-local-ci workflows --repo ../lic
./bin/li-local-ci run-pr --repo lic --pr N --profile legacy
```

Results land in `../benchmarks/data/latest/local-ci-results.json` when `--out` is set (default from sweep).

## Host fallback (no act / no docker)

| Repo | Fast path |
|------|-----------|
| **lic** | `../lic/scripts/local-ci.sh` |
| **li-cursor-agents** | `npm run ci:local` |
| **benchmarks** | `../benchmarks/scripts/ci.sh` if present |

## Merge gate

From **benchmarks**:

```bash
python3 scripts/local-ci-sweep.py --repo lic --pr N
python3 scripts/pr-merge-gate.py --repo lic --pr N
```

Accept merge when local-ci row is `ok: true` even if GHA rollup is empty.

## Org skill copy

The same skill is synced via **roadmap/agent-kit** (`run-local-ci-gha-quota`). Bump agent-kit and run `../roadmap/scripts/install-agent-kit.sh li-local-ci` after kit changes.

See [README.md](../../README.md) for profiles, `config/repo-workflows.json`, and limitations.
