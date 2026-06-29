# ClaudeTokenMonitorBar — 背景与待办

> 创建时间：2026-06-29  
> 当前分支：`feature/v4-companion-app`

---

## 一、项目背景

### 起源

本项目最初以 PR #215 的形式提交到 [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor)（2026-05-28），内容是在该 Python 项目中新增 `macos-stats-bar/` 目录 —— 一个用 Swift/SwiftUI 编写的原生 macOS 菜单栏应用。

### PR 被关闭的原因

2026-06-27，仓库 owner @Maciek-roboblog 关闭了 PR，原文如下：

> *"After the v4 merge, this repo now has a more explicit core boundary: the monitor owns the CLI/TUI, usage warehouse, trust layer, and external state protocol. A native menu bar app is better kept as a separate companion application consuming the v4 state output/protocol instead of being merged into the core package.*
>
> *Closing this PR to keep the main repo focused. A fresh companion-app PR or separate repository proposal that targets the v4 state protocol would be easier to review."*

**核心原因**：v4 之后主仓库明确边界（CLI/TUI + 数据仓库 + 协议层），menu bar app 属于 companion，不应合入核心包。建议改为独立 repo，通过 v4 state protocol 消费数据。

### 当前状态

- 已迁移为独立仓库 `ClaudeTokenMonitorBar-macOS`
- 已实现 v4 state protocol 支持（`StateProtocolReader.swift`，读取 `~/.claude-monitor/state/latest.json`）
- 保留 legacy JSONL 读取作为降级兜底
- 有两个发布版本：
  - **GitHub 版**：`ClaudeMonitor`（直接分发 DMG）
  - **App Store 版**：`AITokenMonitor`（sandbox + bookmark 合规）

---

## 二、已完成的工作

- [x] v4 state protocol 数据结构对接（`StateProtocolReader.swift`）
- [x] `StateProtocolReader` 单元测试，路径可注入
- [x] `TEST_HOST` 配置修复（pbxproj）
- [x] Fable 5 / Opus 4.8 / Haiku 4.5 定价更新
- [x] App Store 合规：Security-Scoped Bookmark
- [x] i18n：英文 + 中文
- [x] 隐私政策页面（`privacy-en.html` / `privacy-zh.html`）
- [x] 版本号推进至 v2.0.0（GitHub）/ v1.1.0（App Store）

---

## 三、待办事项

### 🔴 紧急

- [ ] **回复 PR #215**  
  在 https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor/pull/215#issuecomment-4816417148 下回复，内容：
  - 感谢说明，理解架构边界
  - 告知已建立独立 repo
  - 询问 v4 state protocol 是否有官方文档 / schema
  - 承诺贴上 companion repo 链接

- [ ] **合并 `feature/v4-companion-app` → `main`**  
  v4 支持已稳定，可以合入主分支并打 tag。

### 🟡 重要

- [ ] **向上游申请 community tools 链接**  
  待 repo 建好后，在 PR #215 评论区贴链接，请求 maintainer 在主 repo README 的 "Community" 或 "Related tools" 章节添加一行指向本 repo 的链接。借助主仓库 8.3k star 的自然流量。

- [ ] **补充 docstring 覆盖率至 80%+**  
  CodeRabbit 在 PR #215 中标记：当前覆盖率 57.14%，未达标准线 80%。  
  需要补充注释的文件（优先级从高到低）：
  - `Backend/StateProtocolReader.swift`（新增，几乎无注释）
  - `Backend/MonitoringViewModel.swift`
  - `Backend/TokenDataReader.swift`
  - `StatusBarView.swift`

- [ ] **确认 v4 state protocol schema**  
  目前 `StateProtocolReader.swift` 是基于推断实现的结构体，需要和上游确认：
  - `~/.claude-monitor/state/latest.json` 的完整 schema
  - `schema_version` 字段的版本迭代策略
  - `confidence` / `stale` 字段的语义

- [ ] **创建 GitHub Release（v2.0.0）**  
  当前代码功能已超过 v2.0.0，但尚无对应 Release。  
  参考 `CLAUDE.md` § 3.4 的发布流程：
  ```bash
  gh release create v2.0.0 \
    --title "v2.0.0 - v4 State Protocol + Fable 5 Support" \
    --notes "..."
  gh release upload v2.0.0 ClaudeTokenMonitor-v2.0.0.dmg
  ```

### 🟢 优化 / 长期

- [ ] **App Store v1.1.0 提交**  
  构建检查清单见 `version/1.1.0.md`，尚有未勾选项：
  - Archive 构建 → Xcode Organizer 导出
  - 上传到 App Store Connect
  - 填写更新说明（中/英文已在 `version/1.1.0.md` 中准备好）

- [ ] **适配 v4 limits 显示**  
  `StateProtocolReader` 已解析 `limits.five_hour`（5小时用量百分比 / token 上限 / 重置时间），但 UI 层尚未展示这些数据。可以在 `StatusBarView` detail panel 中增加用量进度条。

- [ ] **自动定价同步**  
  目前定价硬编码在 `TokenDataReader.swift`，每次新模型发布都需要手动更新。可考虑：
  - 从官方文档页面定期爬取 + 写入本地缓存
  - 或提供用户可编辑的定价覆盖配置文件

- [ ] **补充单元测试**  
  当前测试仅覆盖 `StateProtocolReader`，以下模块缺少测试：
  - `TokenDataReader`（JSONL 解析、去重逻辑、定价计算）
  - `MonitoringViewModel`（速率平滑算法）

---

## 四、关键文件索引

| 文件 | 用途 |
|------|------|
| `ClaudeMonitor/Backend/StateProtocolReader.swift` | v4 state protocol 解析 |
| `ClaudeMonitor/Backend/TokenDataReader.swift` | legacy JSONL 解析 + 定价引擎 |
| `ClaudeMonitor/Backend/MonitoringViewModel.swift` | 聚合状态 + 刷新调度 |
| `ClaudeMonitor/StatusBarView.swift` | detail panel UI |
| `ClaudeMonitor/ClaudeMonitorApp.swift` | MenuBarExtra 入口 |
| `version/1.1.0.md` | App Store v1.1.0 发布说明 + 构建清单 |
| `CLAUDE.md` | 开发 / 发布规范（主指导文档）|

---

## 五、上游关系

| 仓库 | 关系 |
|------|------|
| [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) | 灵感来源 + v4 state protocol 协议定义方 |
| [HAOGRE/ClaudeTokenMonitorBar-macOS](https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS) | 本 repo（companion app） |

本项目定位为 **consumer**，通过 v4 state protocol 消费上游数据，不修改 / 不依赖上游代码。
