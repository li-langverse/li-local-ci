#!/usr/bin/env bash
# YAML-first local CI: discover workflows in checkout, run via act.
set -euo pipefail

LI_LOCAL_CI_ROOT="${LI_LOCAL_CI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LI_LOCAL_CI_ROOT
# shellcheck source=act-runner.sh
source "$LI_LOCAL_CI_ROOT/lib/act-runner.sh"
# shellcheck source=repo-profile.sh
source "$LI_LOCAL_CI_ROOT/lib/repo-profile.sh"
# shellcheck source=runner.sh
source "$LI_LOCAL_CI_ROOT/lib/runner.sh"

cmd_run_workflows() {
  local repo="" repo_name="" workflow="" event="" all_pr=0 fallback=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="$2"; shift 2 ;;
      --repo-name) repo_name="$2"; shift 2 ;;
      --workflow) workflow="$2"; shift 2 ;;
      --event) event="$2"; shift 2 ;;
      --all-pr-workflows) all_pr=1; shift ;;
      --no-profile-fallback) fallback=0; shift ;;
      --no-prune) shift ;;
      *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
  done
  [[ -n "$repo" ]] || {
    echo "Usage: workflow-run --repo PATH [--repo-name NAME] [--workflow FILE --event EVENT]" >&2
    exit 1
  }
  repo="$(cd "$repo" && pwd)"
  repo_name="${repo_name:-$(basename "$repo")}"

  local discover="$LI_LOCAL_CI_ROOT/lib/discover_workflows.py"
  local config="$LI_LOCAL_CI_ROOT/config/repo-workflows.json"
  local -a wf_args=("$repo" --repo-name "$repo_name" --config "$config")
  [[ "$all_pr" == 1 ]] && wf_args+=(--all-pr)

  local wf_json
  if [[ -n "$workflow" ]]; then
    wf_json="[{\"file\":\"$workflow\",\"event\":\"${event:-pull_request}\",\"source\":\"cli\"}]"
  else
    wf_json="$(python3 "$discover" "${wf_args[@]}")"
  fi

  local count
  count="$(printf '%s' "$wf_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  if [[ "$count" == "0" ]]; then
    echo "No workflows discovered in $repo" >&2
    if [[ "$fallback" == 1 ]]; then
      local prof
      prof="$(resolve_repo_profile "$repo_name" "$repo")"
      echo "==> profile fallback: $prof" >&2
      cmd_run "$prof" --repo "$repo" --no-prune
      return $?
    fi
    return 1
  fi

  if ! command -v act >/dev/null 2>&1 && [[ -z "${LI_LOCAL_CI_ACT_BIN:-}" ]]; then
    echo "WARN: act not installed — profile fallback" >&2
    if [[ "$fallback" == 1 ]]; then
      local prof
      prof="$(resolve_repo_profile "$repo_name" "$repo")"
      cmd_run "$prof" --repo "$repo" --no-prune
      return $?
    fi
    require_act || return 1
  fi

  local failed=0
  local summary="workflows:"
  while IFS= read -r row; do
    local file ev
    file="$(printf '%s' "$row" | python3 -c "import json,sys; print(json.load(sys.stdin)['file'])")"
    ev="$(printf '%s' "$row" | python3 -c "import json,sys; print(json.load(sys.stdin)['event'])")"
    if run_workflow_act "$repo" "$file" "$ev"; then
      summary+="${file}@${ev}:ok;"
    else
      summary+="${file}@${ev}:fail;"
      failed=1
    fi
  done < <(printf '%s' "$wf_json" | python3 -c "import json,sys; [print(json.dumps(x)) for x in json.load(sys.stdin)]")

  echo "==> $summary" >&2
  if [[ "$failed" -ne 0 && "$fallback" == 1 && "${LI_LOCAL_CI_WORKFLOW_FALLBACK:-}" == "1" ]]; then
    local prof
    prof="$(resolve_repo_profile "$repo_name" "$repo")"
    echo "==> act failed; profile fallback: $prof" >&2
    cmd_run "$prof" --repo "$repo" --no-prune
    return $?
  fi
  return "$failed"
}
