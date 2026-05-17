# li-local-ci

Local CI for the Li ecosystem — run the same checks as GitHub Actions **on your machine** using small Docker images (or the host for heavy LLVM builds). Built to **save GHA minutes** and keep disk usage under control.

## Quick start

```bash
cd li-local-ci
./scripts/build-images.sh          # once: ~150MB node image
./scripts/prune.sh                 # free disk before/after runs

# li-cursor-agents (Node, mock agents — matches GHA ci.yml)
./bin/li-local-ci run li-cursor-agents --repo ../li-cursor-agents

# lic compiler (uses host toolchain — no multi-GB LLVM image unless you opt in)
./bin/li-local-ci run lic-host --repo ../li
```

From **li-cursor-agents**:

```bash
npm run ci:local
```

## Profiles

| Profile | Where it runs | Use for |
|---------|---------------|---------|
| `li-cursor-agents-host` | Host | Full GHA parity (`npm test` + `test:e2e`) — **default for agents** |
| `li-cursor-agents` | Docker `li-local-ci/node:22` | Same steps in container (e2e may need `BENCHMARKS_ROOT`) |
| `li-cursor-agents-quick` | Docker | Unit tests only (fast) |
| `lic-host` | Host (no container) | `./scripts/ci.sh` when LLVM/cmake installed locally |
| `lic-docker` | Docker `li-local-ci/lic:llvm18` | Full lic CI in container (large image — opt-in) |

List profiles: `./bin/li-local-ci list`

## Disk safety

- **`scripts/prune.sh`** — removes exited containers and dangling images (not your tagged `li-local-ci/*` images).
- Runs use **`docker run --rm`** so containers are not left behind.
- Set **`LI_LOCAL_CI_PRUNE=always`** (default) to prune after each run; `never` to skip.
- **`./bin/li-local-ci doctor`** — Docker disk summary + free space warning.

Avoid `docker system prune -a` unless you mean it — it deletes all unused images.

## GitHub Actions quota

Point PR CI to local runs:

1. In each repo, narrow GHA triggers (e.g. `workflow_dispatch` only on `li-cursor-agents`) — see that repo’s workflow.
2. Run `./bin/li-local-ci run <profile>` before push.
3. Optional: add a PR label `run-gha` to re-enable cloud CI when needed.

## Opt-in LLVM Docker image

Only if you have ~4GB+ free and want lic CI fully containerized:

```bash
LI_LOCAL_CI_BUILD_LIC=1 ./scripts/build-images.sh
./bin/li-local-ci run lic-docker --repo ../li
```

## Layout

```
bin/li-local-ci          CLI entry
lib/runner.sh            profile dispatcher
lib/docker.sh            container run + prune helpers
profiles/*.sh            job steps (shell)
docker/node-22/          slim Node 22 image
docker/lic-llvm18/       optional LLVM 18 (Ubuntu)
scripts/build-images.sh
scripts/prune.sh
scripts/doctor.sh
```

## Agent / pre-push

```bash
# In li-cursor-agents or lic before push
../li-local-ci/bin/li-local-ci run li-cursor-agents --repo .
```

License: Apache-2.0 (li-langverse)
