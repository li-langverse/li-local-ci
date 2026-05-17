#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${LI_LOCAL_CI_IMAGE_PREFIX:-li-local-ci}"

echo "==> build ${PREFIX}/node:22"
docker build -t "${PREFIX}/node:22" "$ROOT/docker/node-22"

if [[ "${LI_LOCAL_CI_BUILD_LIC:-}" == "1" ]]; then
  echo "==> build ${PREFIX}/lic:llvm18 (large — ensure disk space)"
  docker build -t "${PREFIX}/lic:llvm18" "$ROOT/docker/lic-llvm18"
else
  echo "Skip lic image (set LI_LOCAL_CI_BUILD_LIC=1 to build)"
fi

echo "Done. Images:"
docker images --format '  {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep "^  ${PREFIX}/" || true
