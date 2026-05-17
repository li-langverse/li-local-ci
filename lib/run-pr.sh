#!/usr/bin/env bash
# Clone PR head and run local CI — replaces GHA for merge gates when quota exceeded.
set -euo pipefail

LI_LOCAL_CI_ROOT="${LI_LOCAL_CI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LI_LOCAL_CI_ROOT
# shellcheck source=docker.sh
source "$LI_LOCAL_CI_ROOT/lib/docker.sh"
# shellcheck source=repo-profile.sh
source "$LI_LOCAL_CI_ROOT/lib/repo-profile.sh"
# shellcheck source=runner.sh
source "$LI_LOCAL_CI_ROOT/lib/runner.sh"
# shellcheck source=workflow-run.sh
source "$LI_LOCAL_CI_ROOT/lib/workflow-run.sh"

cmd_run_pr() {
  local repo="" pr="" profile="" out="" keep=0 workflow="" event="" all_pr=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="$2"; shift 2 ;;
      --pr) pr="$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      --workflow) workflow="$2"; shift 2 ;;
      --event) event="$2"; shift 2 ;;
      --all-pr-workflows) all_pr=1; shift ;;
      --out) out="$2"; shift 2 ;;
      --keep-workspace) keep=1; shift ;;
      *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
  done
  [[ -n "$repo" && -n "$pr" ]] || {
    echo "Usage: li-local-ci run-pr --repo <name> --pr <number> [--profile workflows|legacy] [--workflow FILE] [--out file.json]" >&2
    exit 1
  }
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI required for run-pr" >&2
    exit 1
  fi

  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/li-local-ci-pr.XXXXXX")"
  cleanup() { [[ "$keep" == 1 ]] || rm -rf "$work"; }
  trap cleanup EXIT

  echo "==> clone li-langverse/${repo}#${pr}" >&2
  gh repo clone "li-langverse/${repo}" "$work" -- --depth 50
  (
    cd "$work"
    if ! gh pr checkout "$pr" --force 2>/dev/null; then
      echo "==> gh pr checkout failed; using fetch pull/${pr}/head" >&2
      git fetch origin "pull/${pr}/head:li-local-ci-pr-${pr}"
      git checkout "li-local-ci-pr-${pr}"
    fi
  )

  if [[ -z "$profile" || "$profile" == "auto" ]]; then
    profile="workflows"
  fi
  echo "==> mode $profile" >&2

  local started finished rc=0 runner_note=""
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  set +e
  if [[ "$profile" == "legacy" || "$profile" == "profile" ]]; then
    profile="$(resolve_repo_profile "$repo" "$work")"
    [[ -n "$profile" ]] || {
      echo "No profile for repo $repo" >&2
      exit 1
    }
    echo "==> legacy profile $profile" >&2
    cmd_run "$profile" --repo "$work" --no-prune
    rc=$?
  elif [[ "$profile" == "workflows" ]]; then
    local -a wf_flags=(--repo "$work" --repo-name "$repo")
    [[ -n "$workflow" ]] && wf_flags+=(--workflow "$workflow" --event "${event:-pull_request}")
    [[ "$all_pr" == 1 ]] && wf_flags+=(--all-pr-workflows)
    cmd_run_workflows "${wf_flags[@]}" --no-prune
    rc=$?
    profile="workflows"
  else
    echo "==> legacy profile $profile" >&2
    cmd_run "$profile" --repo "$work" --no-prune
    rc=$?
  fi
  set -e
  finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local key="${repo}#${pr}"
  local result_file="$work/../.li-local-ci-result-$$.json"
  result_file="$(mktemp "${TMPDIR:-/tmp}/li-local-ci-result.XXXXXX.json")"
  python3 - "$result_file" <<PY
import json, sys
row = {
    "key": "${repo}#${pr}",
    "repo": "${repo}",
    "number": int("${pr}"),
    "profile": "${profile}",
    "ok": ${rc} == 0,
    "exit_code": ${rc},
    "started_at": "${started}",
    "finished_at": "${finished}",
}
Path = __import__("pathlib").Path
Path(sys.argv[1]).write_text(json.dumps(row, indent=2) + "\\n")
PY

  if [[ -n "$out" ]]; then
    python3 - "$out" "$result_file" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
out, one = Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text())
data = {"runs": [], "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")}
if out.is_file():
    try:
        data = json.loads(out.read_text())
    except Exception:
        pass
runs = {r.get("key"): r for r in data.get("runs", [])}
runs[one["key"]] = one
data["runs"] = list(runs.values())
data["generated_at"] = one.get("finished_at") or data["generated_at"]
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(data, indent=2) + "\n")
PY
    cat "$result_file"
  else
    cat "$result_file"
  fi
  rm -f "$result_file"
  return "$rc"
}
