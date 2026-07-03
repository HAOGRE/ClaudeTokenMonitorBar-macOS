# Brew Handoff

Context for the Homebrew distribution work. **Status: brew install works via personal tap** (2026-07-03).

## Current state

- ✅ **Personal tap live**: https://github.com/HAOGRE/homebrew-tap
  - `brew tap haogre/tap && brew install --cask claude-token-monitor-bar`
  - Verified locally 2026-07-03: `brew style` clean, install (fetch + sha256 + move app) and uninstall both pass.
- Original PR [#272983](https://github.com/Homebrew/homebrew-cask/pull/272983): closed by bot for incomplete PR template; cannot be reopened (branch was force-pushed/recreated → GitHub 422).
- Replacement PR [#273009](https://github.com/Homebrew/homebrew-cask/pull/273009): **open**, CI failing. Left open pending the blockers below.
- README (EN + zh) now point users to the tap; official cask noted as on hold.

## Why the official homebrew/cask PR cannot merge yet

Exact errors from CI run 28646369893 (`brew audit --cask --online --new`):

1. **Signing/notarization** — "The homebrew/cask tap requires all casks to be signed and notarized by Apple."
   → Needs an Apple Developer ID certificate (Apple Developer Program, $99/yr) + `codesign` + `notarytool` in the release pipeline. Only the maintainer can do this.
2. **Notability** — "Self-submitted GitHub repository not notable enough (<90 forks, <90 watchers and <225 stars)."
   → Repo currently has 2 stars / 0 forks. No code fix possible; requires organic growth.

## Cask definition

`Casks/claude-token-monitor-bar.rb` in the tap (same content as PR #273009 head):
- version 1.2.1, sha256 `8a5554181edbedabc070a1d2c634106d7d3ac2f7b412362bfe42338e2246ce8b` (verified against release asset)
- `livecheck` strategy `:github_latest`, `zap` stanza for `com.haogre.claudetokenmonitor`

## Release checklist addition (new version)

When releasing vX.Y.Z, update the tap:

```bash
shasum -a 256 ClaudeTokenMonitorBar-vX.Y.Z.dmg
# edit Casks/claude-token-monitor-bar.rb in HAOGRE/homebrew-tap: version + sha256, commit & push
```

## Path back to official homebrew/cask (when ready)

1. Join Apple Developer Program; sign (Developer ID Application) + notarize the app in the release pipeline; staple the DMG.
2. Wait until the repo meets notability (≥225 stars or ≥90 forks/watchers).
3. Rebuild/republish DMG, update sha256, push to the `add-claude-token-monitor-bar-1-2-1` branch → PR #273009 re-runs CI.
