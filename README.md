# Claude Token Monitor Bar (CTMB) for macOS

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Version](https://img.shields.io/badge/version-1.4.0-brightgreen.svg)](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Website](https://img.shields.io/badge/Website-ctmb.haogre.com-1f9e63.svg)](https://ctmb.haogre.com)

A native macOS menu bar companion app that monitors your **Claude Code** token usage and costs in real-time. Built entirely in Swift/SwiftUI with zero external dependencies.

**🌐 Official website: [ctmb.haogre.com](https://ctmb.haogre.com)** &nbsp;·&nbsp; [Download](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/latest) &nbsp;·&nbsp; [Screenshots](https://ctmb.haogre.com/#gallery)

**CTMB** is the short name for **Claude Token Monitor Bar**. The shared Xcode schemes are `CTMB` for the GitHub distribution and `CTMB AppStore` for the App Store build.

> **Companion app** for [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) — consumes the v4 state protocol output and displays it in a native macOS menu bar interface.

<p align="center">
  <img src="https://img.shields.io/badge/Universal-Intel%20%2B%20Apple%20Silicon-brightgreen" alt="Universal Binary" />
</p>

---

## Screenshot

### Status Bar

| Active (Token Rates) | Idle (Accumulated Cost) |
|:---:|:---:|
| <img src="assets/screenshots/statusbar-rate.png" width="400" /> | <img src="assets/screenshots/statusbar-cost.png" width="400" /> |

### Dark Mode

| Day | Week | Month |
|:---:|:---:|:---:|
| <img src="assets/screenshots/dark-day.png" width="220" /> | <img src="assets/screenshots/dark-week.png" width="220" /> | <img src="assets/screenshots/dark-month.png" width="220" /> |

### Light Mode

| Day | Week | Month |
|:---:|:---:|:---:|
| <img src="assets/screenshots/light-day.png" width="220" /> | <img src="assets/screenshots/light-week.png" width="220" /> | <img src="assets/screenshots/light-month.png" width="220" /> |

---

## Features

- **Live menu bar indicator** — double-row token rates (↗ input / ↙ output) when Claude is active; switches to accumulated cost when idle
- **Official Rate Limits (v4)** — when [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) is running, shows the 5-hour token window with a color-coded progress bar and reset time
- **Detail panel** — total / today's cost, input / output / cache tokens, top 5 projects by cost, recent 5 records, 30-day trend chart (collapsible)
- **Auto-refresh** — updates every 5 seconds with smoothed per-second rates
- **Deduplication** — skips duplicate entries via `message_id:request_id` hash, matching the Python project's logic exactly
- **Multi-model pricing** — Fable 5, Opus, Sonnet, Haiku with accurate per-token cost calculation
- **i18n** — English and Chinese UI, defaults to system locale
- **Zero dependencies** — pure Swift + SwiftUI, no third-party packages
- **Universal binary** — runs natively on both Intel and Apple Silicon Macs

---

## Install

### Option 1: Homebrew (Recommended) ✅

Available now via the [haogre/tap](https://github.com/HAOGRE/homebrew-tap):

```bash
brew tap haogre/tap
brew trust haogre/tap   # one-time: newer Homebrew requires trusting third-party taps
brew install --cask claude-token-monitor-bar
```

> Submission to the official homebrew/cask repo ([#273009](https://github.com/Homebrew/homebrew-cask/pull/273009)) is on hold — it requires higher project notability (≥225 stars). Starring this repo helps ⭐

Then launch **ClaudeTokenMonitorBar** from Launchpad or Applications folder.

> ✅ Since v1.3.0 the app is **signed and notarized by Apple** — it opens without any Gatekeeper warning. (For older versions ≤1.2.1, allow the app in System Settings → Privacy & Security, or run `xattr -d com.apple.quarantine /Applications/ClaudeTokenMonitorBar.app`.)

### Option 2: Download DMG

1. Go to [Releases](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/latest)
2. Download `ClaudeTokenMonitorBar-v1.4.0.dmg`
3. Open DMG, drag `ClaudeTokenMonitorBar.app` to **Applications**
4. Launch — the app appears in the menu bar immediately (no Dock icon by default)

### Option 3: Build from Source

```bash
git clone https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS.git
cd ClaudeTokenMonitorBar-macOS
open ClaudeMonitor/ClaudeMonitor.xcodeproj
# Select the "CTMB" scheme → Cmd+R
```

**Requirements:** macOS 14.0+, Xcode 16+, Claude Code installed

---

## How It Works

```
~/.claude/projects/<project>/*.jsonl          (Claude Code writes these)
        |
        v
  TokenDataReader.swift     — parse JSONL, extract tokens, calculate cost, deduplicate
        |
        v
  MonitoringViewModel.swift — aggregate totals, compute rates, manage UI state
        |
        v
  ClaudeMonitorApp.swift    — render menu bar label (NSImage, double-row rates)
  StatusBarView.swift       — render detail panel (SwiftUI popup)


~/.claude-monitor/state/latest.json          (claude-code-usage-monitor writes this)
        |
        v
  StateProtocolReader.swift — decode v4 state protocol, extract 5-hour window data
        |
        v
  StatusBarView.swift       — render Official Rate Limits (V4) section (optional)
```

Claude Code writes JSONL session files locally. The app reads them directly — no network requests, no daemon, no external servers. **All data stays on your machine.**

The v4 rate limit section appears **only when** [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) is also running. Without it, all other features work exactly as before.

### Pricing Reference

| Model | Input ($/1M) | Output ($/1M) | Cache Write ($/1M) | Cache Read ($/1M) |
|-------|:---:|:---:|:---:|:---:|
| Fable 5 / Mythos | $10.00 | $50.00 | $12.50 | $1.00 |
| Opus 4.x | $5.00 | $25.00 | $6.25 | $0.50 |
| Sonnet 4.x | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $1.00 | $5.00 | $1.25 | $0.10 |

If a JSONL entry includes `cost_usd`, that value is used directly (most accurate).

Source: [Anthropic Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

---

## Project Structure

```
ClaudeMonitor/
├── ClaudeMonitor.xcodeproj/
└── ClaudeMonitor/
    ├── ClaudeMonitorApp.swift          # App entry, MenuBarExtra, menu bar label
    ├── StatusBarView.swift             # Detail panel UI (SwiftUI)
    ├── SettingsView.swift              # Settings panel
    ├── AppSettings.swift               # Persistent user preferences
    ├── Localization.swift              # English + Chinese strings
    └── Backend/
        ├── TokenDataReader.swift       # JSONL parser, pricing engine, mtime cache
        ├── MonitoringViewModel.swift   # Observable state, auto-refresh, rate smoothing
        ├── StateProtocolReader.swift   # v4 state protocol reader (optional)
        └── BookmarkManager.swift       # Security-scoped bookmark (App Store sandbox)
```

---

## v4 State Protocol Integration

This app is a **consumer** of the [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) v4 state protocol. When the Python tool is running, it writes:

```
~/.claude-monitor/state/latest.json
```

The macOS app reads this file each refresh cycle and displays the official 5-hour rate limit data. If the file doesn't exist (Python tool not installed), the v4 section is simply hidden — no errors, no degraded experience.

---

## Security & Data Flow

For the official rate-limit display, the app reads the OAuth token that Claude Code stores in your macOS Keychain ("Claude Code-credentials") and sends it in a single `GET` request to `https://api.anthropic.com/api/oauth/usage` — the same official endpoint Claude Code's `/usage` command uses. The endpoint is hardcoded; the token is never written to disk, never logged, and never sent anywhere else. If you deny the Keychain prompt, the app silently falls back to local estimation and everything else keeps working. Note the prompt reappears periodically: Claude Code recreates the Keychain item when it refreshes the token (~hourly), which resets any "Always Allow" grant — this is macOS working as designed, not the app asking for more. The code path is fully auditable in [`OAuthUsageReader.swift`](ClaudeMonitor/ClaudeMonitor/Backend/OAuthUsageReader.swift), and you can build from source to verify the binary.

---

## FAQ

**Does this app send data externally?**
Almost none. Local session parsing (`~/.claude/projects/`, `~/.claude-monitor/`) involves zero network requests. The only network call is the official rate-limit query described in [Security & Data Flow](#security--data-flow) — one GET to `api.anthropic.com`, nothing else, and it's skipped entirely if you deny Keychain access.

**Do I need to install claude-code-usage-monitor to use this app?**
No. The core token monitoring (cost, rates, history) works standalone. The **Official Rate Limits (V4)** section is an optional enhancement that requires the Python tool.

**What if `~/.claude/projects` doesn't exist?**
The app shows a hint message and displays data automatically once Claude Code creates sessions.

**How accurate is the cost estimate?**
When `cost_usd` is present in the JSONL entry, that exact value is used. Otherwise, pricing is calculated using the Anthropic official rate table above.

**Why does the app ask for permissions?**

| Permission | Why it's needed |
|------------|-----------------|
| **Folder Access** | To read your local Claude Code session files at `~/.claude/projects/` for token usage statistics. |
| **Keychain Access** | To read the OAuth token stored by Claude Code ("Claude Code-credentials") for fetching official rate limits. The system will prompt for your password—this is expected behavior for accessing another app's Keychain item. |

All usage data stays on your machine. The OAuth token is only ever sent to `api.anthropic.com` (see [Security & Data Flow](#security--data-flow)).

**Why is there both a "Claude Token Monitor" and "AI Token Monitor" version?**
`ClaudeTokenMonitorBar` (this repo) is the open-source GitHub distribution. The App Store version is also named `ClaudeTokenMonitorBar` with full sandbox compliance.

---

## Credits

Native macOS companion app built on top of the architecture established by [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor). The original Python project defined the v4 state protocol, JSONL parsing patterns, token extraction logic, pricing model, and deduplication approach that this app implements in Swift.

---

## License

[MIT](LICENSE)
