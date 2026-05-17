#!/usr/bin/env bash
# Run GitHub Actions workflow YAML via nektos/act (https://github.com/nektos/act).
set -euo pipefail

LI_LOCAL_CI_ROOT="${LI_LOCAL_CI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export LI_LOCAL_CI_ROOT

act_bin() {
  if [[ -n "${LI_LOCAL_CI_ACT_BIN:-}" ]] && [[ -x "${LI_LOCAL_CI_ACT_BIN}" ]]; then
    echo "${LI_LOCAL_CI_ACT_BIN}"
    return 0
  fi
  command -v act
}

require_act() {
  if ! act_bin >/dev/null 2>&1; then
    echo "ERROR: 'act' not found (brew install act). Or set LI_LOCAL_CI_ACT_BIN." >&2
    echo "       Fallback: li-local-ci run-pr --profile <name> (shell profiles)" >&2
    return 1
  fi
}

# Map GHA runner labels → act images (medium images; override with LI_LOCAL_CI_ACT_PLATFORMS)
default_act_platforms() {
  local extra="${LI_LOCAL_CI_ACT_PLATFORMS:-}"
  if [[ -n "$extra" ]]; then
    echo "$extra"
    return
  fi
  echo "-P ubuntu-24.04=catthehacker/ubuntu:act-22.04"
  echo "-P ubuntu-latest=catthehacker/ubuntu:act-latest"
  echo "-P ubuntu-22.04=catthehacker/ubuntu:act-22.04"
  if [[ "$(uname -m)" == "arm64" && -z "${LI_LOCAL_CI_ACT_ARCH:-}" ]]; then
    echo "--container-architecture linux/amd64"
  fi
}

# Run one workflow file with act; repo_abs = checkout root.
run_workflow_act() {
  local repo_abs="$1"
  local workflow_file="$2"
  local event="$3"

  require_act || return 1

  local act
  act="$(act_bin)"
  local -a plat=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && plat+=("$line")
  done < <(default_act_platforms)

  local wf_path="$repo_abs/$workflow_file"
  if [[ ! -f "$wf_path" ]]; then
    echo "WARN: workflow missing: $wf_path" >&2
    return 1
  fi

  echo "==> act event=$event workflow=$workflow_file repo=$repo_abs" >&2

  local -a env_file=()
  if [[ -f "$LI_LOCAL_CI_ROOT/config/act.env" ]]; then
    env_file=(--env-file "$LI_LOCAL_CI_ROOT/config/act.env")
  fi

  local -a act_args=("${plat[@]}" --rm "${env_file[@]}")
  if [[ -n "$event" ]]; then
    act_args=("$event" -W "$workflow_file" "${act_args[@]}")
  else
    act_args=(-W "$workflow_file" --detect-event "${act_args[@]}")
  fi

  # Common Li ecosystem env (matches GHA + profiles). Note: act -e is eventpath, not env.
  act_args+=(
    --env "CURSOR_MOCK=${CURSOR_MOCK:-1}"
    --env "CI=true"
  )
  if [[ -n "${BENCHMARKS_ROOT:-}" ]]; then
    act_args+=(--env "BENCHMARKS_ROOT=$BENCHMARKS_ROOT")
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    act_args+=(--env "GH_TOKEN=$GH_TOKEN" --env "GITHUB_TOKEN=${GITHUB_TOKEN:-$GH_TOKEN}")
  fi

  if [[ "${LI_LOCAL_CI_ACT_VERBOSE:-}" == "1" ]]; then
    act_args+=(--verbose)
  fi
  if [[ "${LI_LOCAL_CI_ACT_DRY:-}" == "1" ]]; then
    act_args+=(--dryrun)
  fi

  # Optional: act -b binds repo dir into container (boolean). Sibling mounts need act v0.2+ container options — use checkout steps in workflow.
  if [[ "${LI_LOCAL_CI_ACT_BIND_WORKSPACE:-}" == "1" ]]; then
    act_args+=(-b)
  fi

  if [[ "${LI_LOCAL_CI_ACT_VERBOSE:-}" == "1" ]]; then
    echo "[act] cd $repo_abs && $act ${act_args[*]}" >&2
  fi
  (cd "$repo_abs" && "$act" "${act_args[@]}")
}

# Discover + run all configured/discovered workflows; returns 0 if all pass.
run_repo_workflows() {
  local repo_abs="$1"
  local repo_name="$2"
  shift 2
  local -a extra=("$@")

  local config="$LI_LOCAL_CI_ROOT/config/repo-workflows.json"
  local discover="$LI_LOCAL_CI_ROOT/lib/discover_workflows.py"
  local -a wf_json=()

  if [[ ${#extra[@]} -gt 0 && "${extra[0]}" == "--workflow" ]]; then
    wf_json="[{\"file\":\"${extra[1]}\",\"event\":\"${extra[3]:-pull_request}\",\"source\":\"cli\"}]"
    shift 4 2>/dev/null || true
  else
    wf_json="$(python3 "$discover" "$repo_abs" --repo-name "$repo_name" --config "$config")"
  fi

  local count
  count="$(echo "$wf_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  if [[ "$count" == "0" ]]; then
    echo "No workflows to run under $repo_abs/.github/workflows" >&2
    return 1
  fi

  local failed=0
  local ran=()
  while IFS= read -r row; do
    local file event
    file="$(echo "$row" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['file'])")"
    event="$(echo "$row" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['event'])")"
    if run_workflow_act "$repo_abs" "$file" "$event"; then
      ran+=("$file:$event:ok")
    else
      ran+=("$file:$event:fail")
      failed=1
    fi
  done < <(echo "$wf_json" | python3 -c "import json,sys; [print(json.dumps(x)) for x in json.load(sys.stdin)]")

  printf '%s\n' "${ran[@]}"
  return "$failed"
}
