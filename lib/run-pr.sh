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

write_run_pr_result() {
  local out_merge="$1" repo="$2" pr="$3" profile="$4" rc="$5" started="$6" finished="$7" summary="${8:-}"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/li-local-ci-row.XXXXXX.json")"
  LI_RUN_PR_REPO="$repo" LI_RUN_PR_PR="$pr" LI_RUN_PR_PROFILE="$profile" \
    LI_RUN_PR_RC="$rc" LI_RUN_PR_STARTED="$started" LI_RUN_PR_FINISHED="$finished" \
    LI_RUN_PR_SUMMARY="$summary" python3 - "$tmp" <<'PY'
import json, os, sys
from pathlib import Path
row = {
    "key": f"{os.environ['LI_RUN_PR_REPO']}#{os.environ['LI_RUN_PR_PR']}",
    "repo": os.environ["LI_RUN_PR_REPO"],
    "number": int(os.environ["LI_RUN_PR_PR"]),
    "profile": os.environ["LI_RUN_PR_PROFILE"],
    "ok": int(os.environ["LI_RUN_PR_RC"]) == 0,
    "exit_code": int(os.environ["LI_RUN_PR_RC"]),
    "started_at": os.environ["LI_RUN_PR_STARTED"],
    "finished_at": os.environ["LI_RUN_PR_FINISHED"],
}
if os.environ.get("LI_RUN_PR_SUMMARY"):
    row["summary"] = os.environ["LI_RUN_PR_SUMMARY"]
Path(sys.argv[1]).write_text(json.dumps(row, indent=2) + "\n")
print(json.dumps(row, indent=2))
PY
  if [[ -n "$out_merge" ]]; then
    python3 "$LI_LOCAL_CI_ROOT/lib/write-result.py" "$tmp" --merge "$out_merge" >/dev/null
  fi
  cat "$tmp"
  rm -f "$tmp"
}

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
  local started finished rc=0 wf_summary=""
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  finish_run_pr() {
    finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    write_run_pr_result "${out:-}" "$repo" "$pr" "${profile:-workflows}" "$rc" "$started" "$finished" "$wf_summary" || true
    [[ "$keep" == 1 ]] || rm -rf "$work"
  }

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

  set +e
  if [[ "$profile" == "legacy" || "$profile" == "profile" ]]; then
    profile="$(resolve_repo_profile "$repo" "$work")"
    [[ -n "$profile" ]] || {
      echo "No profile for repo $repo" >&2
      rc=1
      finish_run_pr
      return 1
    }
    echo "==> legacy profile $profile" >&2
    cmd_run "$profile" --repo "$work" --no-prune
    rc=$?
  elif [[ "$profile" == "workflows" ]]; then
    local -a wf_flags=(--repo "$work" --repo-name "$repo")
    [[ -n "$workflow" ]] && wf_flags+=(--workflow "$workflow" --event "${event:-pull_request}")
    [[ "$all_pr" == 1 ]] && wf_flags+=(--all-pr-workflows)
    cmd_run_workflows "${wf_flags[@]}" --no-prune 2>&1 | tee /tmp/li-local-ci-wf-$$.log >&2
    rc=${PIPESTATUS[0]}
    wf_summary="$(tail -3 "/tmp/li-local-ci-wf-$$.log" 2>/dev/null | tr '\n' ' ' || true)"
    rm -f "/tmp/li-local-ci-wf-$$.log"
    profile="workflows"
  else
    echo "==> legacy profile $profile" >&2
    cmd_run "$profile" --repo "$work" --no-prune
    rc=$?
  fi
  set -e
  finish_run_pr
  return "$rc"
}
