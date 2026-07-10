# Codex Token Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add accurate, local-only Codex token consumption and live refresh to the existing Claude macOS menu bar monitor.

**Architecture:** A value-type `CodexUsageReader` scans known Codex JSONL locations and emits a `CodexUsageSnapshot`. It deduplicates using session cumulative totals, preserves cache/reasoning fields, and optionally parses rate-limit windows. `MonitoringViewModel` polls it with the existing refresh loop, while a separate SwiftUI section renders Codex data without changing Claude aggregation.

**Tech Stack:** Swift 5, SwiftUI, Observation, Foundation JSON serialization, Swift Testing, Xcode project filesystem-synchronized groups.

## Global Constraints

- Read only `$CODEX_HOME/sessions`, `$CODEX_HOME/archived_sessions`, and Codex configuration; never parse or persist conversation text.
- Use the existing `AppSettings.refreshInterval`, whose default is 5 seconds.
- Do not estimate or display dollar cost for Codex subscription token usage.
- Treat missing or null `rate_limits` as unavailable, never as zero.
- Keep existing Claude statistics and costs behavior unchanged.
- Use `apply_patch` for source edits and run the focused test before each production implementation step.

---

### Task 1: Build and test the Codex JSONL reader

**Files:**
- Create: `ClaudeMonitor/ClaudeMonitor/Backend/CodexUsageReader.swift`
- Create: `ClaudeMonitor/ClaudeMonitorTests/CodexUsageReaderTests.swift`

**Interfaces:**
- `CodexUsageReader(homeDirectory: String? = nil)` resolves `CODEX_HOME` or `~/.codex` and exposes `func loadSnapshot(now: Date = Date()) -> CodexUsageSnapshot?`.
- `CodexUsageSnapshot` exposes `today`, `last7Days`, `last30Days`, `currentSession`, `models`, `primaryRateLimit`, `secondaryRateLimit`, `lastTokenAt`, and `scannedFileCount`.
- `CodexTokenTotals` exposes `inputTokens`, `cachedInputTokens`, `outputTokens`, `reasoningOutputTokens`, `totalTokens`, and `requestCount`.

- [ ] **Step 1: Write failing parser tests.** Create temporary `sessions/2026/07/10/rollout-test.jsonl` content containing `session_meta`, `turn_context`, two increasing `token_count` events, one duplicate cumulative event, and one event with primary/secondary limits. Assert that only the two increases count, cached input is not added twice, the model is attributed from `turn_context`, and both limits parse.

```swift
@Test func cumulativeTokenEventsAreDeduplicated() throws {
    let home = try makeCodexHome(jsonl: fixture)
    let snapshot = try #require(CodexUsageReader(homeDirectory: home).loadSnapshot(now: now))
    #expect(snapshot.today.totalTokens == 1_500)
    #expect(snapshot.today.inputTokens == 1_100)
    #expect(snapshot.today.cachedInputTokens == 800)
    #expect(snapshot.today.outputTokens == 400)
    #expect(snapshot.models["gpt-5.4-codex"]?.totalTokens == 1_500)
    #expect(snapshot.primaryRateLimit?.usedPercent == 12)
}
```

- [ ] **Step 2: Run the focused test and confirm the expected missing-type failure.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' test -only-testing:ClaudeMonitorTests/CodexUsageReaderTests`

Expected: FAIL because `CodexUsageReader` and its snapshot types do not exist.

- [ ] **Step 3: Implement the minimal reader.** Scan recursive `sessions` JSONL and top-level `archived_sessions` JSONL. Parse each line as `[String: Any]`, skip malformed lines, track the current model from `turn_context`, and calculate event deltas from cumulative `total_token_usage`. Use `last_token_usage` only when cumulative totals are absent. Reject negative deltas and duplicate non-increasing events. Use `total_tokens` when present; otherwise derive total from noncached input, cached input, output, and reasoning output without double counting.

- [ ] **Step 4: Add remaining parser tests and run them.** Cover `rate_limits: null`, archived files, malformed lines, missing directories, day-window boundaries, current-session grouping, and config model fallback. Run the focused test command again and require all focused tests to pass.

- [ ] **Step 5: Commit the reader.**

```bash
git add ClaudeMonitor/ClaudeMonitor/Backend/CodexUsageReader.swift ClaudeMonitor/ClaudeMonitorTests/CodexUsageReaderTests.swift
git commit -m "feat: parse Codex token usage logs"
```

### Task 2: Integrate Codex snapshots into live monitoring

**Files:**
- Modify: `ClaudeMonitor/ClaudeMonitor/Backend/MonitoringViewModel.swift`
- Test: `ClaudeMonitor/ClaudeMonitorTests/CodexUsageReaderTests.swift`

**Interfaces:**
- Add observable `codexUsage: CodexUsageSnapshot?`, `codexTokenRate: TokenRate`, and `codexAccessRequired: Bool` to `MonitoringViewModel`.
- Keep Claude `monitoringData`, `tokenRate`, and `burnRatePerMin` semantics unchanged.

- [ ] **Step 1: Add a failing rate calculation test** for `MonitoringViewModel.codexRate(previous:current:elapsed:)`: the first snapshot yields zero rate, a later snapshot yields `(newTotal - oldTotal) / elapsed`, and a counter reset never creates a negative rate.

- [ ] **Step 2: Run the focused test and verify it fails for the missing integration behavior.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' test -only-testing:ClaudeMonitorTests/CodexUsageReaderTests`

- [ ] **Step 3: Load Codex in the existing background refresh task.** Resolve the bookmark path when available, construct `CodexUsageReader`, and scan it beside Claude. Update the Codex snapshot on the main actor, preserve the previous snapshot on transient read failure, and smooth `codexTokenRate` over the same five-sample window. Set `codexAccessRequired` only when sandboxed Codex data exists but no bookmark can read it.

- [ ] **Step 4: Run all unit tests.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' test`

Expected: all tests pass with no new warnings caused by Codex integration.

- [ ] **Step 5: Commit the view-model integration.**

```bash
git add ClaudeMonitor/ClaudeMonitor/Backend/MonitoringViewModel.swift ClaudeMonitor/ClaudeMonitorTests/CodexUsageReaderTests.swift
git commit -m "feat: refresh Codex usage with monitor data"
```

### Task 3: Add sandbox-safe Codex folder authorization

**Files:**
- Modify: `ClaudeMonitor/ClaudeMonitor/Backend/BookmarkManager.swift`
- Modify: `ClaudeMonitor/ClaudeMonitor/ClaudeMonitorApp.swift`
- Modify: `ClaudeMonitor/ClaudeMonitor/SettingsView.swift`

**Interfaces:**
- Add `resolvedCodexPath() -> String?`, `hasCodexBookmark`, and `@MainActor requestCodexAccess() -> Bool`.

- [ ] **Step 1: Add a failing bookmark-path test or compile-time usage in the settings test surface** that requires the independent Codex bookmark key and does not overwrite the Claude bookmark.

- [ ] **Step 2: Run the relevant test/build target and observe the missing API failure.**

- [ ] **Step 3: Implement a separate security-scoped bookmark key** (`codexHomeBookmark`) and active URL cache. Preselect `~/.codex`, store only the selected directory, resolve stale bookmarks, and show a settings action for authorization. Keep initial app launch behavior unchanged for Claude; Codex authorization is optional and must not block startup.

- [ ] **Step 4: Run the full unit test target and compile the app target.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' build`

- [ ] **Step 5: Commit sandbox support.**

```bash
git add ClaudeMonitor/ClaudeMonitor/Backend/BookmarkManager.swift ClaudeMonitor/ClaudeMonitor/ClaudeMonitorApp.swift ClaudeMonitor/ClaudeMonitor/SettingsView.swift
git commit -m "feat: add sandbox access for Codex data"
```

### Task 4: Render Codex consumption and limits

**Files:**
- Modify: `ClaudeMonitor/ClaudeMonitor/StatusBarView.swift`
- Modify: `ClaudeMonitor/ClaudeMonitor/Localization.swift`

**Interfaces:**
- Add a private `codexSection` view that maps `selectedPeriod` to `CodexUsagePeriod` and renders token totals, rates, last activity, current session, file count, and optional limits.

- [ ] **Step 1: Add localization keys and a view test fixture expectation** for Codex heading, unavailable state, authorization action, token labels, rate text, and limit reset text.

- [ ] **Step 2: Implement the section below the Claude dashboard.** Hide it only when Codex is absent; show an authorization action when `codexAccessRequired` is true; display no fake zero or cost. Use stable compact dimensions, existing theme colors, SF Symbols, and the current Day/Week/Month segmented control.

- [ ] **Step 3: Add primary and secondary limit cards** only when corresponding windows are present, including percentage, reset time, and a neutral unavailable state when no snapshot exists.

- [ ] **Step 4: Build the app and inspect the resulting diff for accidental Claude UI changes.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' build`

- [ ] **Step 5: Commit the UI and localization.**

```bash
git add ClaudeMonitor/ClaudeMonitor/StatusBarView.swift ClaudeMonitor/ClaudeMonitor/Localization.swift
git commit -m "feat: show Codex token dashboard"
```

### Task 5: Final verification and handoff

**Files:**
- Verify: `docs/superpowers/specs/2026-07-10-codex-token-monitor-design.md`
- Verify: `docs/superpowers/plans/2026-07-10-codex-token-monitor.md`
- Verify: all files changed on `feature/codex-token-monitor`

- [ ] **Step 1: Run focused Codex tests.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' test -only-testing:ClaudeMonitorTests/CodexUsageReaderTests`

- [ ] **Step 2: Run the complete build.**

Run: `cd ClaudeMonitor && xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' build`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Audit the branch.** Confirm the branch is `feature/codex-token-monitor`, working tree changes are intentional, no Codex token is double-counted in tests, and no private endpoint or credential is introduced.

- [ ] **Step 4: Report the branch name, commits, test/build output, data-source limitations, and the sandbox authorization path to the user.**
