# Release notes: 2026-05-25 — github-description-seo

**Status:** Ready for review  
**Repo:** li-langverse/li-local-ci  
**PR:** (open on `chore/github-description-seo`)  
**PH / REQ:** N/A (platform CI metadata)  
**Author:** agent (WP-A4)

---

## Summary (one sentence)

Set canonical GitHub description and README tagline for li-local-ci (HPC local CI, AI agent merge gates).

## Agent continuation (required)

1. Read: `.github/repo-description`, `README.md`, WP-A4 in li-cursor-agents plan.
2. Run: `gh repo view li-langverse/li-local-ci --json description`; after merge, `gh repo edit li-langverse/li-local-ci --description "$(cat .github/repo-description)"` if needed.
3. Then: continue act/workflow work on `main`; no further description pass unless audit flags empty.
4. Blocked on: WP-H2 LICENSE mass-edit — **none**.

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| Metadata | `.github/repo-description` | new file |
| Docs | README tagline | `README.md` |
| Hygiene | `CHANGELOG.md`, release notes | this file |

## Not changed (scope fence)

- `bin/li-local-ci`, act runner, profiles, docker images — **not** touched.
- `lic`, `benchmarks`, `li-cursor-agents` merge gate logic — **not** in this PR.
- SPDX / `LICENSE` files — WP-H2 ADR.

## Breaking changes

None.

## Security

N/A — documentation only.

## Performance

N/A.

## Downstream

N/A — GitHub metadata only.
