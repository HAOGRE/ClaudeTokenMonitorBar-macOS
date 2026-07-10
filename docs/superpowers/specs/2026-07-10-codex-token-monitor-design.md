# Codex Token Monitor Design

**Date:** 2026-07-10
**Branch:** `feature/codex-token-monitor`

## Goal

在现有 Claude token 监控面板中增加 Codex 本地 token 消耗与实时监控，不读取对话正文、不调用未公开网络接口，并在沙盒构建中提供明确的 Codex 数据目录授权流程。

## Findings

Codex CLI/桌面客户端会把会话写入 `$CODEX_HOME/sessions/YYYY/MM/DD/*.jsonl`，默认目录是 `~/.codex/sessions`；部分版本还会把旧会话移动到 `$CODEX_HOME/archived_sessions/*.jsonl`。用量事件是 `event_msg` 且 `payload.type == "token_count"`。

`token_count.info.total_token_usage` 是当前会话的累计值，`last_token_usage` 是本次增量。累计值可能在同一会话中重复写入，因此扫描器必须用累计值去重，不能简单累加每一行。`cached_input_tokens` 是 `input_tokens` 的子集，不能在总 token 中再次相加。`reasoning_output_tokens` 要单独保留，但总量优先使用 Codex 报告的 `total_tokens`。

`payload.rate_limits` 不是所有 Codex 版本都会写入本地日志，且可能为 `null`。界面只在日志确实提供窗口数据时显示 5 小时和周窗口；缺失时显示“配额数据不可用”，不使用猜测值替代。

## Design

### 1. Data reader

新增 `CodexUsageReader.swift`，采用可注入 `codexHome` 的值类型实现，便于 Swift Testing 使用临时目录验证真实 JSONL。

公开数据结构：

- `CodexUsageSnapshot`: 最近 30 天的总量、今日量、当前会话量、日汇总、模型汇总、最后事件时间、扫描文件数以及可选限额窗口。
- `CodexTokenTotals`: `inputTokens`、`cachedInputTokens`、`outputTokens`、`reasoningOutputTokens`、`totalTokens`、`requestCount`。
- `CodexRateLimitWindow`: 使用百分比、窗口分钟数、重置时间。
- `CodexUsagePeriod`: `.today`、`.last7Days`、`.last30Days`，由视图选择器映射。

扫描流程：

1. 优先使用 `CODEX_HOME`，否则使用真实用户 Home 下的 `.codex`。
2. 扫描 `sessions` 递归目录和 `archived_sessions` 顶层 JSONL 文件；无目录时返回 `nil`，代表 Codex 未安装或尚未授权。
3. 读取 `turn_context` 中的模型标记，并把它用于之后的 token 事件；没有标记时使用 `config.toml` 的 `model`，最后回退为 `Codex`。
4. 对每个会话按文件顺序读取 `token_count`，根据累计 `total_token_usage` 与上一个累计值计算增量。累计值不增加的事件视为重复事件并丢弃。
5. 当旧日志缺少累计 `total_tokens` 时，使用 `last_token_usage`，并用时间戳、增量字段和事件序号组成去重键。
6. 将增量按事件时间聚合到今日、近 7 天、近 30 天、当前会话和模型；保留最新的非空限额窗口。

读取器只读 token 元数据，不保存或解析用户消息、助手文本、工具参数和文件内容。

### 2. MonitoringViewModel integration

`MonitoringViewModel` 增加：

- `codexUsage: CodexUsageSnapshot?`
- `codexTokenRate: TokenRate`
- `codexAccessRequired: Bool`

Codex 扫描和 Claude 扫描在同一个后台刷新任务中执行，复用现有 `AppSettings.refreshInterval`，默认每 5 秒刷新。速率使用相邻快照的 token 增量并采用与 Claude 相同的短窗口平滑；首次加载不产生虚假的速率峰值。Codex 扫描失败不会清空上一次有效快照，也不会影响 Claude 面板。

### 3. Sandbox access

`BookmarkManager` 增加独立的 Codex bookmark，避免覆盖已有 Claude bookmark：

- `resolvedCodexPath()`
- `hasCodexBookmark`
- `requestCodexAccess()`

沙盒模式下，Codex 面板在没有授权时显示授权动作；设置页增加 Codex 数据目录授权入口。非沙盒模式直接读取 `~/.codex` 或 `CODEX_HOME`。授权失败只影响 Codex，不阻断应用启动。

### 4. UI

在现有 Claude dashboard 下增加 Codex section，仅当 Codex 有日志或需要授权时显示：

- 标题和最后更新时间/活动状态。
- 根据 Day/Week/Month 选择器展示总 token、Input、Cached、Output、Reasoning。
- 当前输入/输出 token 速率。
- 最新可用的 5 小时和周窗口进度与重置时间；无数据时显示不可用状态。
- 当前会话 token 和扫描文件数作为辅助信息。

Codex 区块不改变 Claude 的 `PeriodReport`、成本计算或已有限额逻辑，也不把 Codex token 混入 Claude 成本。

### 5. Localization

新增 Codex section、授权、配额不可用、更新时间、token 字段和当前会话等中英文文案，避免 UI 写死单一语言。

## Error handling

- JSONL 中的坏行跳过，其他行继续扫描。
- 无法读取单个文件时记录日志并继续处理其他文件。
- 缺少 `last_token_usage` 和累计值的事件忽略。
- 负增量、累计值回退或字段类型异常不进入聚合。
- 没有可读目录时不显示伪造的 0 用量；显示授权/未发现数据状态。
- `rate_limits == null` 或字段不完整时不显示百分比。

## Testing

新增 `CodexUsageReaderTests.swift`，使用临时目录和真实 JSONL 文件覆盖：

1. 解析单个 token_count 事件及 input/cache/output/reasoning/total 字段。
2. 根据累计 token 值去除重复事件，并保留后续真正增加的事件。
3. 解析 `turn_context` 模型并按模型聚合。
4. 聚合今日、近 7 天、近 30 天和当前会话。
5. 解析可用的 primary/secondary rate limits，并对 `null` 返回空值。
6. 扫描 archived sessions、坏行和缺失目录。

构建验证使用仓库规范命令：

```bash
cd ClaudeMonitor
xcodebuild -project ClaudeMonitor.xcodeproj -scheme CTMB -destination 'platform=macOS' build
```
