# Matches li-cursor-agents/.github/workflows/ci.yml (mock backend).
echo "==> npm ci"
npm ci
echo "==> npm run build"
npm run build
echo "==> npm test"
npm test
echo "==> npm run test:e2e"
npm run test:e2e
echo "==> verify run artifacts"
test -n "$(ls data/runs/*.md 2>/dev/null | head -1)"
