# Multi-Agent Token Monitor — 优先级排序 & 技术分析

> 生成日期：2026-06-29  
> 分支：`feature/multi-agent-support`  
> 目标：把 ClaudeTokenMonitorBar 扩展成通用 AI coding agent token 监控工具

---

## 一、主流 Agent 现状评估

> 标准：**真实用户基数 × 本地日志可读性 × 实现难度**

| 优先级 | 工具 | 市场地位 | 本地日志 | 数据可读性 | 实现难度 |
|--------|------|----------|----------|------------|----------|
| 🥇 P0 | **Claude Code** | 已支持 | `~/.claude/projects/*.jsonl` | ✅ JSON，字段完整 | 已完成 |
| 🥈 P1 | **Codex (OpenAI)** | 高，Fortune 500 | `~/.codex/sessions/**/*.jsonl` | ✅ JSONL，有 token_count | 低 |
| 🥈 P1 | **Gemini CLI** | 中（Google 背书） | `~/.gemini/tmp/*/chats/*.jsonl` | ⚠️ 有 session JSONL，无 token count | 中 |
| 🥉 P2 | **Antigravity CLI** | 中（= Gemini CLI 换皮） | `~/.gemini/antigravity*/conversations/*.db` | ⚠️ SQLite + Protobuf BLOB | 高 |
| 🥉 P2 | **GitHub Copilot** | 高，行业标准 | 无本地日志 | ❌ 纯云端 | 需 API |
| 🥉 P2 | **Cursor** | 高，Fortune 500 | `~/Library/Application Support/Cursor/` | ❌ Chromium SQLite | 高 |
| 🔲 P3 | **Amp (ampcode.com)** | 新兴 CLI | 未知 | 未调查 | 待验证 |
| 🔲 P3 | **Kiro (AWS)** | 新兴 IDE | 未知 | 未调查 | 待验证 |
| 🔲 P3 | **OpenCode** | 新兴开源 CLI | `~/.config/opencode/` | ⚠️ 仅 config，无 token 日志 | 待验证 |
| 🔲 P4 | **Trae (ByteDance)** | 国内 | 未知 | 未调查 | 待验证 |
| 🔲 P4 | **通义灵码 Tongyi Lingma** | 国内 Alibaba | 未知 | 未调查 | 待验证 |
| 🔲 P4 | **Kimi Code** | 国内 Moonshot | 未知 | 未调查 | 待验证 |
| 🔲 P4 | **DeepSeek coding** | 国内 + 海外关注 | 未知 | 未调查 | 待验证 |
| 🚫 退市 | **Codex API (老版本)** | 已 deprecated | N/A | N/A | 不做 |

---

## 二、已确认日志格式详解

### 2.1 Claude Code（已支持）

```
~/.claude/projects/-<path-encoded>/<session-uuid>.jsonl
```

每行 JSON，关键字段：
```json
{
  "type": "assistant",
  "message": {
    "model": "claude-opus-4-8",
    "usage": {
      "input_tokens": 1234,
      "output_tokens": 567,
      "cache_creation_input_tokens": 890,
      "cache_read_input_tokens": 100
    }
  },
  "cost_usd": 0.0042
}
```

---

### 2.2 Codex / OpenAI Codex App（P1 — 最推荐下一个做）

```
~/.codex/sessions/YYYY/MM/DD/rollout-<ISO8601>-<session-uuid>.jsonl
```

每行 JSON，三种 type：
- `session_meta` — 会话元数据
- `response_item` — 消息内容
- **`event_msg` — 含 token_count（关键）**

Token 数据字段（在 `event_msg` 中）：
```json
{
  "type": "event_msg",
  "timestamp": "ISO8601",
  "payload": {
    "type": "token_count",
    "info": {
      "total_token_usage": {
        "input_tokens": 90362,
        "cached_input_tokens": 52352,
        "output_tokens": 2084,
        "reasoning_output_tokens": 520,
        "total_tokens": 92446
      },
      "last_token_usage": {
        "input_tokens": 36060,
        "cached_input_tokens": 21888,
        "output_tokens": 331,
        "reasoning_output_tokens": 0,
        "total_tokens": 36391
      },
      "model_context_window": 258400
    },
    "rate_limits": {
      "primary": {
        "used_percent": 3.0,
        "window_minutes": 300,
        "resets_at": 1780298394
      },
      "secondary": {
        "used_percent": 0.0,
        "window_minutes": 10080,
        "resets_at": 1780885394
      },
      "plan_type": "plus"
    }
  }
}
```

**亮点**：有 rate_limits（5小时窗口 / 周窗口），跟 Claude Code 的使用限制结构高度类似！  
**注意**：`total_token_usage` 是累计值，`last_token_usage` 是本次 turn 增量。

---

### 2.3 Gemini CLI（P1 — 有数据但不完整）

```
~/.gemini/tmp/<project-name>/chats/session-<ISO8601>-<id>.jsonl
```

格式：MongoDB 风格的 `$set` 操作日志：
```json
{"sessionId": "...", "projectHash": "...", "startTime": "...", "kind": "session_meta"}
{"$set": {"messages": [...]}}
```

**问题**：消息内容有，但目前实测 **没有 usageMetadata / token count 字段**。  
Gemini API 返回 `usageMetadata`（含 promptTokenCount / candidatesTokenCount），但 Gemini CLI 当前版本似乎不落地到本地文件。  
**结论**：可以读 session，但 token count 需要等 Gemini CLI 支持或用模型估算。

---

### 2.4 Antigravity CLI（P2 — 难度高）

```
~/.gemini/antigravity-cli/conversations/<uuid>.db    (SQLite)
~/.gemini/antigravity/conversations/<uuid>.db        (SQLite)
```

SQLite 表：`steps`, `gen_metadata`, `trajectory_meta`, `executor_metadata`  
**问题**：`gen_metadata.data` 是 Protobuf 二进制，需要逆向 proto schema。  
**结论**：Antigravity 就是 Gemini CLI 换皮（配置显示用 `Gemini 3.1 Pro`），优先级低。

---

### 2.5 GitHub Copilot（P2 — 无本地数据）

```
~/.config/github-copilot/versions.json   （仅版本号）
```

**结论**：没有本地 token 日志。所有 usage 数据在 GitHub 服务器端。  
如要支持，需要调用 GitHub REST API（需 OAuth），实现成本较高。

---

### 2.6 Cursor（P2 — 逆向成本高）

```
~/Library/Application Support/Cursor/    （Chromium 风格）
```

**结论**：Cursor 数据存在 Chromium SQLite/IndexedDB，没有公开的 token 日志格式。  
需要逆向，实现成本高，暂不优先。

---

## 三、实施优先级路线图

### Phase 1（当前）— 基础设施准备
- [x] 创建 `feature/multi-agent-support` 分支
- [ ] 设计 `AgentReader` 协议（抽象不同 agent 的读取方式）
- [ ] 设计 UI 多 agent 切换/展示方案

### Phase 2 — Codex 支持（最优先，2-3天）
**为什么先做 Codex**：
1. 本地 JSONL，格式清晰，和 Claude Code 几乎同构
2. 有 rate_limits（5小时窗口），用户价值高
3. 你已经装了 Codex，可以立即测试
4. OpenAI 用户基数大

技术要点：
- 扫描 `~/.codex/sessions/YYYY/MM/DD/*.jsonl`
- 过滤 `payload.type == "token_count"` 的行
- 读 `payload.info.total_token_usage` + `payload.rate_limits`
- 模型信息从 `config.toml` 读取（`model = "gpt-5.5"`）

### Phase 3 — Gemini CLI 支持（1-2天）
**策略**：先支持 session 展示，token count 用 tiktoken 估算  
技术要点：
- 扫描 `~/.gemini/tmp/*/chats/*.jsonl`
- 解析 `$set.messages` 数组
- 基于内容估算 token（Gemini 官方 tokenizer 或近似）

### Phase 4 — GitHub Copilot API 支持（可选）
需要 OAuth flow，实现成本最高，视用户需求决定。

---

## 四、架构建议

### 现有架构（`TokenDataReader.swift`）
```
TokenDataReader → 读 ~/.claude/projects/ JSONL
StateProtocolReader → 读 ~/.claude-monitor/state/ JSON
```

### 扩展方向
```swift
protocol AgentLogReader {
    var agentName: String { get }          // "Claude Code", "Codex", "Gemini"
    var icon: String { get }               // SF Symbol 或自定义图标
    var isInstalled: Bool { get }          // 判断 agent 是否安装
    func readSessions() -> [AgentSession]  // 读取会话列表
    func readCurrentUsage() -> TokenUsage  // 当前使用量
}

// 具体实现
class CodexLogReader: AgentLogReader { ... }
class GeminiCLILogReader: AgentLogReader { ... }
```

### UI 建议
- StatusBar 显示：切换当前监控的 agent（Claude / Codex / Gemini）
- 或：展示所有 agent 的聚合视图（"今日所有 AI 花费 $X.XX"）

---

## 五、待确认工具（P3/P4）

这些工具需要进一步调查本地日志格式后才能排期：

| 工具 | 调查方法 | 负责人 |
|------|----------|--------|
| Amp (ampcode.com) | 安装后检查 `~/.amp/` | 待定 |
| Kiro (kiro.dev) | 安装后检查 `~/Library/Application Support/kiro/` | 待定 |
| Trae (ByteDance) | 联系官方或逆向 | 待定 |
| 通义灵码 | 官方文档或逆向 | 待定 |

---

## 六、不做的工具

以下工具暂时跳过，原因明确：

- **WorkBuddy / Hermes / Pi Agent / Oh My Pi / Gajae Code / ZCode / MiMoCode / Droid / Qoder / Mistral Vibe** — 无法找到确认用户基数或本地日志格式
- **Antigravity** — Gemini CLI 换皮，优先通过 Gemini CLI 支持覆盖
- **Codex (旧版 API)** — OpenAI 已 deprecated

---

*文档会随开发进展更新*
