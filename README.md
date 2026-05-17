# li-local-ci

Local CI for the Li ecosystem — run **the same GitHub Actions workflow YAML** as cloud CI on your machine, using [nektos/act](https://github.com/nektos/act). Built to **save GHA minutes** and keep merge gates honest when `statusCheckRollup` is red or skipped.

## YAML-first (default)

1. Clone PR branch (`run-pr`) or use a local checkout (`workflows`)
2. **Discover** `.github/workflows/*.yml` (or read `config/repo-workflows.json`)
3. **Run** each selected workflow with `act` and the right event (`pull_request`, `workflow_dispatch`, …)
4. Write result to `benchmarks/data/latest/local-ci-results.json` for `pr-merge-gate.py`

Shell **profiles** (`profiles/*.sh`) remain as **fallback** when `act` is missing or you pass `--profile legacy`.

### Install act

```bash
brew install act
./bin/li-local-ci doctor   # should show act version
```

First run pulls runner images (`catthehacker/ubuntu:act-22.04`, …). Override:

```bash
export LI_LOCAL_CI_ACT_PLATFORMS="-P ubuntu-24.04=catthehacker/ubuntu:act-22.04"
```

## Agent swarm / merge queue (GHA quota)

When GitHub Actions minutes are exhausted, **li-cursor-agents** supervisor runs:

1. `benchmarks/scripts/local-ci-sweep.py` on merge-candidate PRs
2. `li-local-ci run-pr` → **workflows on the PR branch** (not org-wide YAML)
3. `pr-merge-gate.py` accepts **local-ci pass** instead of `statusCheckRollup` green

```bash
# Single PR — runs that repo's CI workflow YAML via act
./bin/li-local-ci run-pr --repo li-cursor-agents --pr 2

# Explicit workflow + event
./bin/li-local-ci run-pr --repo lic --pr 14 --workflow .github/workflows/ci.yml --event pull_request

# Local checkout (no gh clone)
./bin/li-local-ci workflows --repo ../li-cursor-agents

# Legacy shell profile (no act)
./bin/li-local-ci run-pr --repo li-cursor-agents --pr 2 --profile legacy
```

Disable swarm sweep: `LI_USE_LOCAL_CI=0` on the dashboard/supervisor.

## Config

| File | Purpose |
|------|---------|
| `config/repo-workflows.json` | Per-repo default workflow + event when discovery is ambiguous |
| `config/act.env` | Non-secret env passed to all act runs (`CURSOR_MOCK=1`, …) |

Discovery skips workflows whose names match `release`, `notify`, `upstream`, etc. Use `--all-pr-workflows` to run every `pull_request` workflow in a repo.

## Profiles (fallback / fast loop)

| Profile | Where | Use for |
|---------|-------|---------|
| `li-cursor-agents-host` | Host | Full tests without act |
| `li-cursor-agents-quick` | Docker | Unit tests only |
| `lic-host` | Host | `./scripts/ci.sh` |

List: `./bin/li-local-ci list`

## Disk safety

- `docker run --rm` for profile mode; act manages its own containers
- `./scripts/prune.sh` — safe prune after runs
- `./bin/li-local-ci doctor` — disk + act check

## Layout

```
bin/li-local-ci
lib/act-runner.sh          # act invocation
lib/discover_workflows.py  # YAML on: → event
lib/workflow-run.sh        # discover + run
lib/run-pr.sh              # clone PR + workflows
config/repo-workflows.json
config/act.env
profiles/*.sh              # legacy shell CI
```

## Limitations

- **Not every GHA feature works in act** (services, caches, some actions). Heavy workflows (lic + sibling checkouts) may need `LI_LOCAL_CI_BINDS` or host `lic-host` profile.
- Workflows must exist **on the PR branch** — that is the point: local CI matches what you merge.
