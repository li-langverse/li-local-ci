# Full GHA parity on host (recommended for e2e — uses sibling benchmarks fixtures).
export CURSOR_MOCK=1
export CI=true
export BENCHMARKS_ROOT="${BENCHMARKS_ROOT:-../benchmarks}"
npm ci
npm run build
npm test
npm run test:e2e
test -n "$(ls data/runs/*.md 2>/dev/null | head -1)"
