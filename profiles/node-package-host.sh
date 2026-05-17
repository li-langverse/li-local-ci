# Generic org package / small repo with package.json
if [[ -f package-lock.json ]]; then
  npm ci
elif [[ -f pnpm-lock.yaml ]]; then
  corepack enable 2>/dev/null || true
  pnpm install --frozen-lockfile
else
  npm install
fi
if grep -q '"test"' package.json 2>/dev/null; then
  npm test
elif grep -q '"build"' package.json 2>/dev/null; then
  npm run build
else
  echo "No test script — profile ok (lint skipped)"
fi
