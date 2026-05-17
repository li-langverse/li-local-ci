# Fast loop — unit tests only (no e2e; e2e needs full profile on host or Docker with fixtures).
npm ci
npm run build
CURSOR_MOCK=1 node --test 'dist/**/*.test.js'
