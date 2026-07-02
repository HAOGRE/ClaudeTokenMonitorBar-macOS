# ClaudeTokenMonitor Tokenscope Redesign Handoff

最后更新：2026-07-02

## 当前状态

当前分支是 `feature/ui-redesign`，远端是 `origin/feature/ui-redesign`。

最新提交：

```text
7f2ed46 feat: wire Tokenscope tool metrics
```

当前目标基本完成：面板已经按 Tokenscope 方向重做，外层多余套壳已去掉，主题切换按钮已恢复，MCP / Skill / request / cost trend 等数据不再是 UI 占位，而是从本地 Claude JSONL 和用户配置里聚合。

## 已完成

### 1. Tokenscope 风格 UI

主要文件：

- `ClaudeMonitor/ClaudeMonitor/StatusBarView.swift`
- `ClaudeMonitor/ClaudeMonitor/Localization.swift`

已实现内容：

- `Day / Week / Month` 分段切换。
- `TOTAL TOKENS` hero 区域、输入/输出 split bar、柱状图、模型 token 分布、模型成本圆环图。
- Requests 和 Cost Trend 两张小卡片。
- MCP Calls、Skill Calls、Daily Activity 热力图。
- 去掉了 popover 外层浅绿色背景套壳，现在根视图就是单个圆角 panel。
- 恢复右上角主题按钮。点击后在 light / dark 间切换，并用 `@AppStorage("tokenscopeThemeMode")` 保存。
- 右上角 camera 按钮会把当前 panel 截图复制到剪贴板。
- 设置页里旧的“项目 / 最近记录”显示项文案已改为 MCP Calls / Skill Calls。

### 2. 真实数据接入

主要文件：

- `ClaudeMonitor/ClaudeMonitor/Backend/TokenDataReader.swift`
- `ClaudeMonitor/ClaudeMonitor/Backend/MonitoringViewModel.swift`

已实现内容：

- `UsageEntry` 增加 `sessionId`、`mcpServers`、`skills`。
- 从 Claude JSONL 的 assistant `tool_use` 中解析：
  - `mcp__<server>__<tool>` 形式的 MCP 调用。
  - `Skill` tool 的 `input.skill`。
- 从 user message 的 `<command-name>/skill-name</command-name>` 解析 slash-command Skill 调用。
- 读取 `~/.claude.json`：
  - 顶层 `mcpServers`
  - `projects[*].mcpServers`
- 读取 `~/.claude/skills` 目录作为用户安装 Skill 白名单。
- 如果 macOS sandbox 读不到 `~/.claude.json` 或 `~/.claude/skills`，会降级为按 JSONL 中真实出现过的 MCP / Skill 调用统计，避免界面永远显示 0。
- 同一个 assistant message 可能分多行写入 JSONL，现在按 message id 合并，避免去重时丢掉 tool calls。
- Day / Week / Month 改为自然日、自然周、自然月窗口。
- `deltaTokens`、`deltaCost` 使用上一周期计算。
- `reqTrend` 使用真实 request count。
- `costTrend` 使用真实 USD cost。
- `sessions` 使用 `sessionId` 去重。
- 模型统计会去掉模型 id 末尾的 `-YYYYMMDD` 日期后缀再聚合。
- 热力图按 Tokenscope 的 26 周、周日对齐方式生成，token 总量包含 input、output、cache read、cache creation。

### 3. 已推送提交

本轮相关提交按时间从早到晚：

```text
0ffc129 feat: match Tokenscope analytics layout
6a7cde0 fix: keep daily activity visible
f3dbe95 chore: remove obsolete chart display setting
7f2ed46 feat: wire Tokenscope tool metrics
```

## 验证记录

最近代码构建命令：

```bash
cd ClaudeMonitor
xcodebuild -project ClaudeMonitor.xcodeproj -scheme ClaudeMonitor -destination 'platform=macOS' build
```

本轮交接前重新执行过，结果是 `BUILD SUCCEEDED`。

源码里还有一个可以后续单独清理的点：

```text
ClaudeMonitor/ClaudeMonitor/Backend/MonitoringViewModel.swift:121
nonisolated(unsafe) private var autoRefreshTask: Task<Void, Never>?
```

之前完整编译时它会提示 `nonisolated(unsafe)` 对该属性无效，但不阻塞当前 build。

## 换电脑后建议先做

1. 拉最新分支：

```bash
git fetch origin
git switch feature/ui-redesign
git pull --ff-only origin feature/ui-redesign
```

2. 本地构建：

```bash
cd ClaudeMonitor
xcodebuild -project ClaudeMonitor.xcodeproj -scheme ClaudeMonitor -destination 'platform=macOS' build
```

3. 运行 app 后做一次视觉 smoke test：

- light / dark 模式切换是否生效。
- popover 外层是否已经没有第二层浅绿色背景。
- Day / Week / Month 切换是否稳定。
- 当前没有数据的周期是否显示空状态。
- Daily Activity 是否在底部完整可见。
- MCP Calls / Skill Calls 是否按本机数据出现。

4. 如果 MCP / Skill 仍显示 0，先检查权限和本机数据：

```bash
ls -la ~/.claude.json ~/.claude/skills ~/.claude/projects
rg '"name":"mcp__|\"name\": \"mcp__|\"name\":\"Skill\"|\"name\": \"Skill\"|<command-name>' ~/.claude/projects -g '*.jsonl'
```

如果 `~/.claude/skills` 不存在，但 JSONL 里有 Skill 调用，当前代码会使用日志降级统计，界面仍应能显示出现过的 Skill。

## 待办

优先级从高到低：

1. 对真实 app 截图做一轮视觉校准，尤其是 header 宽度、右上角按钮、空数据时的留白、深色模式对比度。
2. 确认 sandbox 权限体验。如果用户只授权 `~/.claude/projects`，`~/.claude.json` 和 `~/.claude/skills` 可能读不到。当前有降级统计，但如果要严格复刻 Tokenscope 的“已安装总数”，后续可以让授权目录改为 `~/.claude`。
3. `StatusBarView.swift` 仍偏大，可以后续拆成 `HeroSection`、`ModelSections`、`ToolCallSections`、`HeatmapSection`、`HeaderControls`。
4. `nonisolated(unsafe)` warning 可以单独清理，但不要和 UI 校准混在一个提交里。
5. 如果要发布 GitHub 版本，按 `AGENTS.md` 的发布流程重新跑 Release build 和 DMG，不要直接拿 Debug build。

## 注意点

- 这次目标不是新增模型定价，未改 `ModelPricing` 表。
- `MCP Calls` 和 `Skill Calls` 的显示开关仍复用旧的 `showProjectSection`、`showRecentSection` UserDefaults key，只是 UI 文案变了。这样可以避免迁移设置。
- camera 按钮当前是“复制 panel 截图到剪贴板”，不是保存文件。
- 如果后续继续做 pixel-perfect，优先用用户给的 Tokenscope 原图对照，不要再回到旧版四宫格设计。
