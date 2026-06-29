import Foundation
import os.log

// MARK: - Codex Log Reader
//
// 读取 OpenAI Codex（本地 App）的会话日志。
//
// 文件路径：~/.codex/sessions/YYYY/MM/DD/*.jsonl
//
// 每个 JSONL 文件（rollout-<ISO8601>-<uuid>.jsonl）每行是一个 JSON 对象，有三种 type：
//   - session_meta   会话元数据
//   - response_item  消息内容（含用户/助理消息、工具调用等）
//   - event_msg      事件消息（含 token_count，这是我们需要的）
//
// token_count 事件结构：
// {
//   "type": "event_msg",
//   "timestamp": "ISO8601",
//   "payload": {
//     "type": "token_count",
//     "info": {
//       "total_token_usage": { "input_tokens": N, "output_tokens": N, "cached_input_tokens": N, ... },
//       "last_token_usage":  { ... }   // 本次 turn 增量
//     },
//     "rate_limits": {
//       "primary":   { "used_percent": 3.0, "window_minutes": 300, "resets_at": unix_ts },
//       "secondary": { "used_percent": 0.0, "window_minutes": 10080, "resets_at": unix_ts },
//       "plan_type": "plus"
//     }
//   }
// }
//
// 注意：
//   - total_token_usage 是会话内累计值（含历史消息），不能直接累加
//   - last_token_usage  是本次 turn 增量，用于逐 turn 统计
//   - 每次 token_count 事件对应一个 turn，取最后一条 token_count 更可靠

final class CodexLogReader: AgentLogReader {
    var kind: AgentKind { .codex }

    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "codexreader")

    private var codexHome: String {
        realHomeDirectory() + "/.codex"
    }

    private var sessionsPath: String {
        codexHome + "/sessions"
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: codexHome)
    }

    // MARK: - 模型名称（从 config.toml 读取）

    private func readCurrentModel() -> String {
        let configPath = codexHome + "/config.toml"
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return "gpt-unknown"
        }
        // 解析 model = "gpt-5.5" 格式
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("model") {
                // model = "gpt-5.5"  or  model="gpt-5.5"
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let raw = parts[1...].joined(separator: "=")
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if !raw.isEmpty { return raw }
                }
            }
        }
        return "gpt-unknown"
    }

    // MARK: - OpenAI 模型定价（每百万 token 美元）

    private struct OpenAIPricing {
        let input: Double
        let output: Double
        let cachedInput: Double

        static func forModel(_ model: String) -> OpenAIPricing {
            let m = model.lowercased()
            // GPT-5.5 (Codex App 当前默认模型，2026)
            if m.contains("gpt-5.5") {
                return OpenAIPricing(input: 30.0, output: 60.0, cachedInput: 7.5)
            }
            // GPT-5
            if m.contains("gpt-5") {
                return OpenAIPricing(input: 30.0, output: 60.0, cachedInput: 7.5)
            }
            // GPT-4o
            if m.contains("4o-mini") {
                return OpenAIPricing(input: 0.15, output: 0.60, cachedInput: 0.075)
            }
            if m.contains("4o") {
                return OpenAIPricing(input: 2.5, output: 10.0, cachedInput: 1.25)
            }
            // GPT-4 turbo
            if m.contains("gpt-4") {
                return OpenAIPricing(input: 10.0, output: 30.0, cachedInput: 5.0)
            }
            // o3 / o4
            if m.contains("o4") || m.contains("o3") {
                return OpenAIPricing(input: 10.0, output: 40.0, cachedInput: 2.5)
            }
            // 默认（GPT-4o 兜底）
            return OpenAIPricing(input: 2.5, output: 10.0, cachedInput: 1.25)
        }

        func calculateCost(input: Int, output: Int, cachedInput: Int) -> Double {
            let cost = (Double(input) / 1_000_000) * self.input
                + (Double(output) / 1_000_000) * self.output
                + (Double(cachedInput) / 1_000_000) * self.cachedInput
            return (cost * 1_000_000).rounded() / 1_000_000
        }
    }

    // MARK: - 主接口

    func loadAllData(since: Date?, daysBack: Int) -> AllAgentData {
        guard isInstalled else {
            return .empty(for: .codex)
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsPath) else {
            return .empty(for: .codex)
        }

        let model = readCurrentModel()
        let pricing = OpenAIPricing.forModel(model)

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let dailyCutoff = calendar.date(byAdding: .day, value: -daysBack, to: startOfToday)
            ?? now.addingTimeInterval(-Double(daysBack) * 86400)

        let jsonlFiles = findJsonlFiles(in: sessionsPath, fileManager: fileManager)

        var allEntries: [UsageEntry] = []
        var todayEntries: [UsageEntry] = []
        var projectEntries: [String: [UsageEntry]] = [:]
        var dailyEntries: [Date: [UsageEntry]] = [:]

        // 跟踪最新的限额状态（取最后一个非 nil 的）
        var latestRateLimit: AgentRateLimitState? = nil

        for filePath in jsonlFiles {
            let (entries, rateLimit) = parseSessionFile(at: filePath, model: model, pricing: pricing)

            if let rl = rateLimit { latestRateLimit = rl }

            // 从文件路径提取日期作为项目键（YYYY/MM/DD）
            let projectKey = extractDateKey(from: filePath)

            for entry in entries {
                // 跳过 since 之前的记录
                if let s = since, entry.timestamp < s { continue }

                projectEntries[projectKey, default: []].append(entry)
                allEntries.append(entry)

                if entry.timestamp >= startOfToday {
                    todayEntries.append(entry)
                }

                if entry.timestamp >= dailyCutoff {
                    let comps = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
                    if let dayDate = calendar.date(from: comps) {
                        dailyEntries[dayDate, default: []].append(entry)
                    }
                }
            }
        }

        allEntries.sort { $0.timestamp < $1.timestamp }

        let totalCost        = allEntries.reduce(0) { $0 + $1.costUsd }
        let todayCost        = todayEntries.reduce(0) { $0 + $1.costUsd }
        let totalInput       = allEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutput      = allEntries.reduce(0) { $0 + $1.outputTokens }
        let todayInput       = todayEntries.reduce(0) { $0 + $1.inputTokens }
        let todayOutput      = todayEntries.reduce(0) { $0 + $1.outputTokens }
        let projectCosts     = projectEntries.mapValues { $0.reduce(0) { $0 + $1.costUsd } }
        let daily = dailyEntries
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, cost: $0.value.reduce(0) { $0 + $1.costUsd },
                    tokens: $0.value.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }) }

        logger.info("Codex: \(allEntries.count) 条记录，今日成本 \(String(format: "$%.4f", todayCost))")

        return AllAgentData(
            agentKind: .codex,
            totalCost: totalCost,
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            totalCacheReadTokens: 0,  // Codex 称其为 cachedInput，归入 input 成本计算
            todayCost: todayCost,
            todayInputTokens: todayInput,
            todayOutputTokens: todayOutput,
            todayCacheReadTokens: 0,
            recentEntries: Array(allEntries.suffix(5)),
            projectCosts: projectCosts,
            dailyHistory: daily,
            rateLimitState: latestRateLimit
        )
    }

    // MARK: - 解析单个会话文件

    /// 解析一个 rollout JSONL 文件
    /// 返回：(UsageEntry 列表, 最新限额状态)
    private func parseSessionFile(
        at filePath: String,
        model: String,
        pricing: OpenAIPricing
    ) -> ([UsageEntry], AgentRateLimitState?) {

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return ([], nil)
        }

        var entries: [UsageEntry] = []
        var latestRateLimit: AgentRateLimitState? = nil

        // 会话的基准时间戳（用于没有 token_count 事件时的兜底）
        var sessionTimestamp: Date? = nil
        // 同一 turn 内避免重复计入：turn_id → 是否已记录
        var processedTurns = Set<String>()

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let type = json["type"] as? String ?? ""
            let timestamp = parseTimestamp(json["timestamp"] as? String ?? "")

            // 记录会话起始时间
            if type == "session_meta", sessionTimestamp == nil {
                sessionTimestamp = timestamp
            }

            // 只处理 event_msg 类型
            guard type == "event_msg",
                  let payload = json["payload"] as? [String: Any],
                  (payload["type"] as? String) == "token_count"
            else { continue }

            guard let info = payload["info"] as? [String: Any],
                  let lastUsage = info["last_token_usage"] as? [String: Any]
            else { continue }

            // 提取本次 turn 的增量 token 数
            let inputTokens  = intValue(lastUsage, keys: ["input_tokens"])
            let outputTokens = intValue(lastUsage, keys: ["output_tokens"])
            let cachedInput  = intValue(lastUsage, keys: ["cached_input_tokens"])

            // 跳过没有实际 token 的事件
            guard inputTokens > 0 || outputTokens > 0 else { continue }

            // 使用 timestamp 或 session 时间
            let entryTime = timestamp ?? sessionTimestamp ?? Date()

            // 避免在同一文件内重复计入（同一时间点的多条 token_count）
            let turnKey = "\(entryTime.timeIntervalSince1970):\(inputTokens):\(outputTokens)"
            guard !processedTurns.contains(turnKey) else { continue }
            processedTurns.insert(turnKey)

            // 成本计算
            let costUsd = pricing.calculateCost(
                input: inputTokens - cachedInput,
                output: outputTokens,
                cachedInput: cachedInput
            )

            entries.append(UsageEntry(
                id: turnKey,
                timestamp: entryTime,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: 0,
                cacheReadTokens: cachedInput,
                costUsd: costUsd,
                model: model,
                messageId: turnKey,
                requestId: ""
            ))

            // 提取最新限额状态
            if let rateLimits = payload["rate_limits"] as? [String: Any],
               let primary = rateLimits["primary"] as? [String: Any],
               let usedPercent = primary["used_percent"] as? Double,
               let windowMinutes = primary["window_minutes"] as? Int,
               let resetsAt = primary["resets_at"] as? Int {
                let resetsDate = Date(timeIntervalSince1970: Double(resetsAt))
                let remaining = resetsDate.timeIntervalSinceNow
                let resetsDesc: String
                if remaining > 0 {
                    let hours = Int(remaining) / 3600
                    let mins  = (Int(remaining) % 3600) / 60
                    if hours > 0 {
                        resetsDesc = "in \(hours)h \(mins)m"
                    } else {
                        resetsDesc = "in \(mins)m"
                    }
                } else {
                    resetsDesc = "已重置"
                }
                latestRateLimit = AgentRateLimitState(
                    windowMinutes: windowMinutes,
                    usedPercent: usedPercent,
                    resetsDescription: resetsDesc
                )
            }
        }

        return (entries, latestRateLimit)
    }

    // MARK: - 工具方法

    private func findJsonlFiles(in dirPath: String, fileManager: FileManager) -> [String] {
        guard let enumerator = fileManager.enumerator(atPath: dirPath) else { return [] }
        var result: [String] = []
        while let relative = enumerator.nextObject() as? String {
            if relative.hasSuffix(".jsonl") {
                result.append((dirPath as NSString).appendingPathComponent(relative))
            }
        }
        return result
    }

    /// 从文件路径 .../sessions/2026/06/28/rollout-....jsonl 提取日期键 "2026/06/28"
    private func extractDateKey(from filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        // sessions 目录后面是 YYYY/MM/DD
        if let sessIdx = components.firstIndex(of: "sessions"),
           sessIdx + 3 < components.count {
            let year  = components[sessIdx + 1]
            let month = components[sessIdx + 2]
            let day   = components[sessIdx + 3]
            return "\(year)/\(month)/\(day)"
        }
        return "unknown"
    }

    private func parseTimestamp(_ str: String) -> Date? {
        guard !str.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }

    private func intValue(_ dict: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let v = dict[key] as? Int,    v > 0 { return v }
            if let v = dict[key] as? Double, v > 0 { return Int(v) }
        }
        return 0
    }
}
