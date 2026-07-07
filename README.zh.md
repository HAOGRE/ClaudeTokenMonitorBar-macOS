# Claude Token Monitor Bar (CTMB) for macOS

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Version](https://img.shields.io/badge/version-1.3.0-brightgreen.svg)](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

一款原生 macOS 菜单栏伴侣应用，实时监控 **Claude Code** 的 Token 使用量和费用。完全使用 Swift/SwiftUI 构建，零外部依赖。

**CTMB** 是 **Claude Token Monitor Bar** 的简称。共享的 Xcode Scheme 为 GitHub 分发的 `CTMB` 和 App Store 版本的 `CTMB AppStore`。

> **[Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) 的伴侣应用** — 消费 v4 状态协议输出并在原生 macOS 菜单栏界面中显示。

<p align="center">
  <img src="https://img.shields.io/badge/Universal-Intel%20%2B%20Apple%20Silicon-brightgreen" alt="Universal Binary" />
</p>

---

## 截图

### 状态栏

| 活跃状态 (Token 速率) | 空闲状态 (累计费用) |
|:---:|:---:|
| <img src="assets/screenshots/statusbar-rate.png" width="400" /> | <img src="assets/screenshots/statusbar-cost.png" width="400" /> |

### 深色模式

| 日视图 | 周视图 | 月视图 |
|:---:|:---:|:---:|
| <img src="assets/screenshots/dark-day.png" width="220" /> | <img src="assets/screenshots/dark-week.png" width="220" /> | <img src="assets/screenshots/dark-month.png" width="220" /> |

### 浅色模式

| 日视图 | 周视图 | 月视图 |
|:---:|:---:|:---:|
| <img src="assets/screenshots/light-day.png" width="220" /> | <img src="assets/screenshots/light-week.png" width="220" /> | <img src="assets/screenshots/light-month.png" width="220" /> |

---

## 功能特性

- **实时菜单栏指示器** — Claude 活跃时显示双行 Token 速率（↗ 输入 / ↙ 输出）；空闲时切换到累计费用
- **官方速率限制 (v4)** — 当 [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) 运行时，显示 5 小时 Token 窗口，带颜色编码的进度条和重置时间
- **详情面板** — 总费用/今日费用、输入/输出/缓存 Token、按费用排序的前 5 个项目、最近 5 条记录、30 天趋势图（可折叠）
- **自动刷新** — 每 5 秒更新一次，速率经过平滑处理
- **去重** — 通过 `message_id:request_id` 哈希跳过重复条目，与 Python 项目逻辑完全一致
- **多模型定价** — Fable 5、Opus、Sonnet、Haiku，精确的按 Token 费用计算
- **国际化** — 英文和中文界面，默认跟随系统语言
- **零依赖** — 纯 Swift + SwiftUI，无第三方包
- **通用二进制** — 原生运行于 Intel 和 Apple Silicon Mac

---

## 安装

### 方案 1：Homebrew（推荐）✅

已可通过 [haogre/tap](https://github.com/HAOGRE/homebrew-tap) 安装：

```bash
brew tap haogre/tap
brew trust haogre/tap   # 一次性：新版 Homebrew 要求信任第三方 tap
brew install --cask claude-token-monitor-bar
```

> 提交到官方 homebrew/cask 仓库的 PR（[#273009](https://github.com/Homebrew/homebrew-cask/pull/273009)）暂时搁置——官方要求项目知名度（≥225 star）。欢迎点 star 支持 ⭐

然后从启动台或应用程序文件夹启动 **ClaudeTokenMonitorBar**。

> ✅ 自 v1.3.0 起，应用已经过 **Apple 签名与公证**——首次启动不会再有 Gatekeeper 安全警告。（旧版本 ≤1.2.1 需在系统设置 → 隐私与安全性中放行，或执行 `xattr -d com.apple.quarantine /Applications/ClaudeTokenMonitorBar.app`）

### 方案 2：下载 DMG

1. 前往 [Releases](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/latest)
2. 下载 `ClaudeTokenMonitorBar-v1.3.0.dmg`
3. 打开 DMG，将 `ClaudeTokenMonitorBar.app` 拖入**应用程序**
4. 启动 — 应用立即出现在菜单栏（默认无 Dock 图标）

### 方案 3：从源码构建

```bash
git clone https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS.git
cd ClaudeTokenMonitorBar-macOS
open ClaudeMonitor/ClaudeMonitor.xcodeproj
# 选择 "CTMB" Scheme → Cmd+R
```

**要求：** macOS 14.0+、Xcode 16+、已安装 Claude Code

---

## 工作原理

```
~/.claude/projects/<project>/*.jsonl          (Claude Code 写入)
        |
        v
  TokenDataReader.swift     — 解析 JSONL、提取 Token、计算费用、去重
        |
        v
  MonitoringViewModel.swift — 聚合总计、计算速率、管理 UI 状态
        |
        v
  ClaudeMonitorApp.swift    — 渲染菜单栏标签（NSImage、双行速率）
  StatusBarView.swift       — 渲染详情面板（SwiftUI 弹出层）


~/.claude-monitor/state/latest.json          (claude-code-usage-monitor 写入)
        |
        v
  StateProtocolReader.swift — 解码 v4 状态协议，提取 5 小时窗口数据
        |
        v
  StatusBarView.swift       — 渲染官方速率限制 (V4) 区域（可选）
```

Claude Code 在本地写入 JSONL 会话文件。应用直接读取 — 无网络请求、无守护进程、无外部服务器。**所有数据保留在您的机器上。**

v4 速率限制区域**仅在** [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) 同时运行时显示。没有它，其他所有功能完全照常工作。

### 定价参考

| 模型 | 输入 ($/1M) | 输出 ($/1M) | 缓存写入 ($/1M) | 缓存读取 ($/1M) |
|-------|:---:|:---:|:---:|:---:|
| Fable 5 / Mythos | $10.00 | $50.00 | $12.50 | $1.00 |
| Opus 4.x | $5.00 | $25.00 | $6.25 | $0.50 |
| Sonnet 4.x | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $1.00 | $5.00 | $1.25 | $0.10 |

如果 JSONL 条目包含 `cost_usd`，则直接使用该值（最准确）。

来源：[Anthropic 定价](https://platform.claude.com/docs/en/about-claude/pricing)

---

## 项目结构

```
ClaudeMonitor/
├── ClaudeMonitor.xcodeproj/
└── ClaudeMonitor/
    ├── ClaudeMonitorApp.swift          # 应用入口、MenuBarExtra、菜单栏标签
    ├── StatusBarView.swift             # 详情面板 UI (SwiftUI)
    ├── SettingsView.swift              # 设置面板
    ├── AppSettings.swift               # 持久化用户偏好
    ├── Localization.swift              # 英文 + 中文字符串
    └── Backend/
        ├── TokenDataReader.swift       # JSONL 解析器、定价引擎、mtime 缓存
        ├── MonitoringViewModel.swift   # 可观察状态、自动刷新、速率平滑
        ├── StateProtocolReader.swift   # v4 状态协议读取器（可选）
        └── BookmarkManager.swift       # 安全域书签（App Store 沙盒）
```

---

## v4 状态协议集成

本应用是 [claude-code-usage-monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) v4 状态协议的**消费者**。当 Python 工具运行时，它写入：

```
~/.claude-monitor/state/latest.json
```

macOS 应用在每个刷新周期读取此文件并显示官方 5 小时速率限制数据。如果文件不存在（未安装 Python 工具），v4 区域会隐藏 — 无错误、无降级体验。

---

## 安全与数据流说明

为了显示官方额度，应用会读取 Claude Code 存储在 macOS 钥匙串中的 OAuth 令牌（"Claude Code-credentials"），并仅用它向官方接口 `https://api.anthropic.com/api/oauth/usage` 发送一个 `GET` 请求——与 Claude Code 的 `/usage` 命令同源。接口地址硬编码在代码中；令牌不落盘、不写日志、不发往任何其他地方。如果你拒绝钥匙串授权，应用会静默回落到本地估算，其余功能不受影响。授权弹窗会周期性重新出现：Claude Code 大约每小时续期令牌时会重建钥匙串条目，导致 "Always Allow" 授权随旧条目失效——这是 macOS 的正常安全机制，不是应用在索取更多权限。完整代码路径见 [`OAuthUsageReader.swift`](ClaudeMonitor/ClaudeMonitor/Backend/OAuthUsageReader.swift)，也可自行编译验证。

---

## 常见问题

**此应用会向外发送数据吗？**
几乎没有。本地会话解析（`~/.claude/projects/`、`~/.claude-monitor/`）零网络请求。唯一的网络调用是上文[安全与数据流说明](#安全与数据流说明)中的官方额度查询——仅向 `api.anthropic.com` 发一个 GET，别无其他；拒绝钥匙串授权后该请求也完全不会发生。

**我需要安装 claude-code-usage-monitor 才能使用此应用吗？**
不需要。核心 Token 监控（费用、速率、历史）可独立工作。**官方速率限制 (V4)** 区域是需要 Python 工具的可选增强功能。

**如果 `~/.claude/projects` 不存在怎么办？**
应用会显示提示信息，Claude Code 创建会话后自动显示数据。

**费用估算有多准确？**
当 JSONL 条目包含 `cost_usd` 时，直接使用该精确值。否则，使用上述 Anthropic 官方费率表计算定价。

**为什么应用请求权限？**

| 权限 | 用途 |
|------------|-----------------|
| **文件夹访问** | 读取本地 Claude Code 会话文件位于 `~/.claude/projects/`，用于 Token 使用统计。 |
| **钥匙串访问** | 读取 Claude Code 存储的 OAuth 令牌（"Claude Code-credentials"），用于获取官方速率限制。系统会提示输入密码 — 这是访问其他应用钥匙串项目的预期行为。 |

所有用量数据保留在您的机器上。OAuth 令牌仅会发往 `api.anthropic.com`（见[安全与数据流说明](#安全与数据流说明)）。

**为什么会有 "Claude Token Monitor" 和 "AI Token Monitor" 两个版本？**
`ClaudeTokenMonitorBar`（本仓库）是开源 GitHub 分发版本。App Store 版本也名为 `ClaudeTokenMonitorBar`，完全符合沙盒要求。

---

## 致谢

原生 macOS 伴侣应用基于 [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) 建立的架构。原始 Python 项目定义了本应用在 Swift 中实现的 v4 状态协议、JSONL 解析模式、Token 提取逻辑、定价模型和去重方法。

---

## 许可证

[MIT](LICENSE)
