#!/usr/bin/env bash
# Safe disk cleanup — does not remove tagged li-local-ci/* images.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/docker.sh
source "$ROOT/lib/docker.sh"

echo "==> prune exited containers (li-local-ci runs)"
prune_safe

echo "==> optional: remove unused build cache older than 48h (set LI_LOCAL_CI_PRUNE_BUILD_CACHE=1)"
if [[ "${LI_LOCAL_CI_PRUNE_BUILD_CACHE:-}" == "1" ]]; then
  docker builder prune -f --filter "until=48h"
fi

disk_summary
