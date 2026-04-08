# Claude Monitor — macOS Menu Bar App

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A native macOS menu bar application that monitors your Claude Code token usage and costs in real-time — built entirely in Swift with zero external dependencies.

> **Inspired by** [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor), the original Python-based terminal monitor that pioneered real-time Claude usage tracking. This project reimplements the same core logic (token parsing, cost calculation, deduplication) as a native macOS menu bar app.

---

## ✨ Features

### Menu Bar Display
- **Active state** — iStat Menus–style double-row indicator showing live input/output token rates (↗/↙)
- **Idle state** — Shows accumulated session cost (`$2.45`) when no activity is detected
- Updates every second; negligible CPU overhead

### Detail Panel (click to open)
| Section | Content |
|---------|---------|
| **Header** | App title · last-update timestamp · manual refresh button |
| **Real-time rates** | Input and output token speeds with direction indicators |
| **Stats grid (2×2)** | Total cost · Input tokens · Output tokens · Cache reads |
| **Top 5 Projects** | Ranked by cost with proportional progress bars |
| **Recent Records** | Last 5 API calls — model tag, tokens, cost, timestamp |
| **Footer** | Error message or dominant model name · Quit button |

### Smart & Efficient
- **Zero dependencies** — Pure Swift + SwiftUI, no third-party packages
- **Direct file access** — Reads JSONL files from `~/.claude/projects`, no daemon required
- **Sandbox-compatible** — Temporary read-only entitlement for `~/.claude/`
- **Deduplication** — Skips duplicate entries via `message_id:request_id` hash
- **Multi-format support** — Handles `input_tokens`, `inputTokens`, `prompt_tokens`, etc.

---

## 🚀 Quick Start

### Requirements
- **macOS 14.0 (Sonoma)** or later
- **Xcode 15.3** or later
- **Claude Code** installed (data source: `~/.claude/projects/`)

### Build & Run

```bash
# Clone the repository
git clone https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor.git
cd Claude-Code-Usage-Monitor

# Open the Xcode project
open macos/ClaudeMonitor/ClaudeMonitor.xcodeproj

# Press Cmd+R to build and run
# The app appears in the menu bar — no Dock icon
```

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+R`  | Manual refresh (when detail panel is open) |
| `Cmd+Q`  | Quit the application |

---

## 🏗️ Architecture

```
macos/ClaudeMonitor/
├── ClaudeMonitor.xcodeproj/         # Xcode project
└── ClaudeMonitor/
    ├── ClaudeMonitorApp.swift        # @main entry — MenuBarExtra, label rendering
    ├── StatusBarView.swift           # Detail panel UI and all sub-components
    ├── Backend/
    │   ├── TokenDataReader.swift     # JSONL parser · pricing engine · deduplication
    │   └── MonitoringViewModel.swift # @Observable state · auto-refresh · rate smoothing
    └── Assets.xcassets/             # App icon, accent color
```

### Component Overview

#### `ClaudeMonitorApp.swift`
- App entry point using `@main` SwiftUI `App` protocol
- Creates a `MenuBarExtra` with:
  - **Label view**: renders a compact `NSImage` — double-row rates when active, cost string when idle
  - **Content view**: the full detail panel (`StatusBarView`)
- Custom `NSImage` drawing mimics iStat Menus–style compact display

#### `StatusBarView.swift`
- Six-section panel layout inside a 340 pt wide `VStack`
- Each section is a private SwiftUI component:
  `RateBar` · `StatCell` · `ProjectRow` · `RecentEntryRow` · `SectionHeader`
- Highlights the rate bar with an accent-colored border when token activity is detected

#### `TokenDataReader.swift`
- Resolves the **real home directory** via `getpwuid()` to bypass sandbox home remapping
- Recursively enumerates all `.jsonl` files under `~/.claude/projects/`
- Parses each line with `JSONSerialization`, extracting tokens from multiple candidate paths:
  - `message.usage` → `usage` → top-level (priority order varies by `type`)
- Calculates cost using built-in pricing (aligned with the original Python `pricing.py`):

  | Model  | Input ($/1M) | Output ($/1M) | Cache Create | Cache Read |
  |--------|:------------:|:-------------:|:------------:|:----------:|
  | Opus   | $15.00       | $75.00        | $18.75       | $1.50      |
  | Sonnet | $3.00        | $15.00        | $3.75        | $0.30      |
  | Haiku  | $0.25        | $1.25         | $0.30        | $0.03      |

- Prefers `cost_usd` / `cost` fields from JSONL when available (AUTO mode)

#### `MonitoringViewModel.swift`
- `@Observable` + `@MainActor` class powering all UI state
- Auto-refreshes every **5 seconds** via a background `Task`
- Computes per-second token rates with a **5-sample sliding average** to smooth spikes
- Skips rate calculation on the first load to avoid a false initial surge

---

## 🔍 How It Works

```
~/.claude/projects/<project>/*.jsonl
            │
            ▼
   TokenDataReader.swift
   (parse JSON lines · extract tokens · calculate cost · deduplicate)
            │
            ▼
   MonitoringViewModel.swift
   (aggregate totals · compute rates · manage @Observable state)
            │
            ▼
   StatusBarView.swift + ClaudeMonitorApp.swift
   (render detail panel · update menu bar label every second)
```

Claude Code writes one JSONL file per session. Each line is a JSON record:

```json
{
  "type": "assistant",
  "timestamp": "2025-04-08T10:23:45.123Z",
  "message": {
    "model": "claude-sonnet-4-5",
    "usage": {
      "input_tokens": 1024,
      "output_tokens": 512,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 200
    }
  }
}
```

Supported token field variants:
- `input_tokens` / `inputTokens` / `prompt_tokens`
- `output_tokens` / `outputTokens` / `completion_tokens`
- `cache_creation_input_tokens` / `cache_creation_tokens` / `cacheCreationInputTokens`
- `cache_read_input_tokens` / `cache_read_tokens` / `cacheReadInputTokens`

---

## ❓ FAQ

**Does the app send any data externally?**
No. It only reads local JSONL files. There are no network requests and no external servers.

**Why does it need Xcode to build?**
Pre-compiled binaries are not currently distributed. Building from source takes under a minute.

**What if `~/.claude/projects` doesn't exist?**
The app starts normally and shows a footer message. Data appears automatically once Claude Code creates sessions.

**How accurate is the cost estimate?**
The pricing table matches the official Anthropic API documentation and mirrors the Python implementation. If a JSONL entry includes a `cost_usd` field, that value is used directly.

**Does it work under macOS App Sandbox?**
Yes. A temporary-exception entitlement grants read-only access to `~/.claude/`. No App Store submission is required.

---

## 🙏 Inspiration & Credits

This project is a native macOS reimplementation of the ideas pioneered by
**[Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor)**.

The original Python project provided:
- The foundation for reading and parsing Claude Code JSONL session files
- Token extraction strategies and multi-field-name fallback logic
- The pricing model and model-detection approach (Opus / Sonnet / Haiku)
- Per-project cost aggregation and deduplication via `message_id:request_id`

This Swift version keeps the same logic faithfully while adding native macOS integration,
a live-updating menu bar indicator, and zero runtime dependencies.

---

## 📝 License

[MIT License](../LICENSE) — free to use, modify, and distribute.

