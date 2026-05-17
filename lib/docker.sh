#!/usr/bin/env bash
# Docker helpers — small images, --rm containers, safe prune.
set -euo pipefail

LI_LOCAL_CI_IMAGE_PREFIX="${LI_LOCAL_CI_IMAGE_PREFIX:-li-local-ci}"

image_tag() {
  echo "${LI_LOCAL_CI_IMAGE_PREFIX}/$1"
}

image_exists() {
  docker image inspect "$(image_tag "$1")" >/dev/null 2>&1
}

docker_run_workspace() {
  local image_name="$1"
  local repo_abs="$2"
  local profile_script="$3"
  shift 3
  local -a extra_env=("$@")
  local image prof_base
  image="$(image_tag "$image_name")"
  prof_base="$(basename "$profile_script")"

  if ! image_exists "$image_name"; then
    echo "Image missing: $image — run: ./scripts/build-images.sh" >&2
    return 1
  fi

  local -a env_args=()
  for e in "${extra_env[@]}"; do
    [[ -n "$e" ]] && env_args+=(-e "$e")
  done

  docker run --rm \
    --label "li-local-ci.run=1" \
    -v "${repo_abs}:/workspace" \
    -v "${LI_LOCAL_CI_ROOT}/profiles:/opt/li-local-ci/profiles:ro" \
    -w /workspace \
    "${env_args[@]}" \
    "$image" \
    bash -lc "set -euo pipefail; bash /opt/li-local-ci/profiles/${prof_base}"
}

prune_safe() {
  # Exited li-local-ci containers + dangling layers only (keeps tagged li-local-ci/*).
  docker container prune -f --filter "label=li-local-ci.run" 2>/dev/null || docker container prune -f
  docker image prune -f
}

disk_summary() {
  echo "=== Docker disk ==="
  docker system df 2>/dev/null || echo "(docker not running)"
  echo ""
  echo "=== Filesystem (/) ==="
  df -h / 2>/dev/null | tail -1 || true
}

warn_low_disk() {
  local avail_gb
  avail_gb="$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -n "$avail_gb" && "$avail_gb" -lt 5 ]]; then
    echo "WARN: less than 5GB free on / — run: li-local-ci prune" >&2
    return 1
  fi
  return 0
}
