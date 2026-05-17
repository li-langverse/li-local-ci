#!/usr/bin/env bash
# Map li-langverse repo name → li-local-ci profile (host preferred for e2e).
set -euo pipefail

resolve_repo_profile() {
  local repo="$1"
  case "$repo" in
    lic) echo "lic-host" ;;
    li-cursor-agents) echo "li-cursor-agents-host" ;;
    benchmarks) echo "benchmarks-host" ;;
    lip | lit | lis) echo "node-package-host" ;;
    li-std-* | li-httpd | li-net | li-demo | li-language) echo "node-package-host" ;;
    roadmap) echo "node-package-host" ;;
    *)
      if [[ -f "${2:-}/scripts/ci.sh" ]]; then
        echo "lic-host"
      elif [[ -f "${2:-}/package.json" ]]; then
        echo "node-package-host"
      else
        echo ""
      fi
      ;;
  esac
}
