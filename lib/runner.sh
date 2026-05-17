#!/usr/bin/env bash
set -euo pipefail

LI_LOCAL_CI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LI_LOCAL_CI_ROOT
# shellcheck source=docker.sh
source "$LI_LOCAL_CI_ROOT/lib/docker.sh"

PROFILES_DIR="$LI_LOCAL_CI_ROOT/profiles"

cmd_list() {
  echo "Profiles (profiles/<name>.sh):"
  for f in "$PROFILES_DIR"/*.sh; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .sh)"
    mode="docker"
    [[ -f "$PROFILES_DIR/${name}.meta" ]] && source "$PROFILES_DIR/${name}.meta"
    printf "  %-24s %s\n" "$name" "${LI_LOCAL_CI_MODE:-docker} ${LI_LOCAL_CI_IMAGE:-}"
    unset LI_LOCAL_CI_MODE LI_LOCAL_CI_IMAGE
  done
}

cmd_doctor() {
  disk_summary
  warn_low_disk || true
  echo ""
  if command -v act >/dev/null 2>&1; then
    echo "act: $(act --version 2>/dev/null | head -1)"
  else
    echo "act: NOT INSTALLED (brew install act) — run-pr falls back to shell profiles"
  fi
  echo ""
  echo "Images:"
  docker images --format '  {{.Repository}}:{{.Tag}}\t{{.Size}}' 2>/dev/null | grep -E "^  ${LI_LOCAL_CI_IMAGE_PREFIX}/" || echo "  (none — run ./scripts/build-images.sh)"
}

cmd_run() {
  local profile=""
  local repo=""
  local prune_after="${LI_LOCAL_CI_PRUNE:-always}"
  local dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        repo="$2"
        shift 2
        ;;
      --no-prune)
        prune_after=never
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      -h | --help)
        echo "Usage: li-local-ci run <profile> [--repo PATH] [--no-prune] [--dry-run]"
        exit 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [[ -z "$profile" ]]; then
          profile="$1"
        else
          echo "Unexpected argument: $1" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$profile" ]]; then
    echo "Profile required. Try: li-local-ci list" >&2
    exit 1
  fi

  local profile_sh="$PROFILES_DIR/${profile}.sh"
  if [[ ! -f "$profile_sh" ]]; then
    echo "Unknown profile: $profile (missing $profile_sh)" >&2
    exit 1
  fi

  if [[ -z "$repo" ]]; then
    repo="$(pwd)"
  fi
  repo="$(cd "$repo" && pwd)"

  # shellcheck source=/dev/null
  [[ -f "$PROFILES_DIR/${profile}.meta" ]] && source "$PROFILES_DIR/${profile}.meta"

  local mode="${LI_LOCAL_CI_MODE:-docker}"
  local image="${LI_LOCAL_CI_IMAGE:-node:22}"

  echo "==> li-local-ci run profile=$profile repo=$repo mode=$mode"
  warn_low_disk || true

  if [[ "$dry_run" == 1 ]]; then
    echo "[dry-run] would execute $profile_sh"
    exit 0
  fi

  local start
  start="$(date +%s)"
  local rc=0

  if [[ "$mode" == "host" ]]; then
    (
      set -euo pipefail
      cd "$repo"
      bash "$profile_sh"
    ) || rc=$?
  else
    docker_run_workspace "$image" "$repo" "$profile_sh" \
      CURSOR_MOCK=1 CI=true \
      || rc=$?
  fi

  local end elapsed
  end="$(date +%s)"
  elapsed=$((end - start))

  if [[ "$prune_after" == "always" ]]; then
    echo "==> prune (safe)"
    prune_safe
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "==> PASS profile=$profile (${elapsed}s)"
  else
    echo "==> FAIL profile=$profile (${elapsed}s) exit=$rc" >&2
  fi
  exit "$rc"
}
