import Foundation
import os.log

// MARK: - 数据模型（与实际 JSONL 格式对应）

/// 从 JSONL 文件解析出的原始使用记录
struct UsageEntry: Identifiable {
    let id: String          // message_id + request_id 组合
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUsd: Double
    let model: String
    let messageId: String
    let requestId: String
}

/// token 使用统计数据
struct UsageStatistics {
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheReadTokens: Int
    let totalCacheCreationTokens: Int
    let totalCost: Double
    let modelDistribution: [String: Int]
    let entries: [UsageEntry]

    init(entries: [UsageEntry]) {
        self.entries = entries
        self.totalInputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        self.totalOutputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        self.totalCacheReadTokens = entries.reduce(0) { $0 + $1.cacheReadTokens }
        self.totalCacheCreationTokens = entries.reduce(0) { $0 + $1.cacheCreationTokens }
        self.totalCost = entries.reduce(0) { $0 + $1.costUsd }

        var modelDist: [String: Int] = [:]
        for entry in entries {
            let model = entry.model.isEmpty ? "unknown" : entry.model
            modelDist[model, default: 0] += 1
        }
        self.modelDistribution = modelDist
    }
}

// MARK: - 定价模型（与 Python pricing.py 对应）

/// 获取模型的定价（每百万 token 的美元价格）
private struct ModelPricing {
    let input: Double
    let output: Double
    let cacheCreation: Double
    let cacheRead: Double

    /// 根据模型名称获取定价（与 Python FALLBACK_PRICING 保持一致）
    static func forModel(_ model: String) -> ModelPricing {
        let lower = model.lowercased()
        if lower.contains("opus") {
            return ModelPricing(input: 15.0, output: 75.0, cacheCreation: 18.75, cacheRead: 1.5)
        } else if lower.contains("haiku") {
            return ModelPricing(input: 0.25, output: 1.25, cacheCreation: 0.3, cacheRead: 0.03)
        } else {
            // 默认 Sonnet 定价
            return ModelPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.3)
        }
    }

    /// 计算 token 成本（USD）
    func calculateCost(input: Int, output: Int, cacheCreation: Int, cacheRead: Int) -> Double {
        let cost = (Double(input) / 1_000_000) * self.input
            + (Double(output) / 1_000_000) * self.output
            + (Double(cacheCreation) / 1_000_000) * self.cacheCreation
            + (Double(cacheRead) / 1_000_000) * self.cacheRead
        return (cost * 1_000_000).rounded() / 1_000_000
    }
}

// MARK: - Token 数据读取器

/// Token 数据读取器 - 替代 Python reader.py
/// 读取 ~/.claude/projects 下的所有 .jsonl 文件
class TokenDataReader {
    private let logger = Logger(subsystem: "com.claudetokenmonitorbar.app", category: "tokenreader")

    // 静态 formatter 实例，进程生命周期内只创建一次
    // ISO8601DateFormatter 线程安全；DateFormatter 不线程安全，但 loadData() 有 isLoading 互斥保护
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        return ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    // 文件级解析缓存：key = 绝对路径，value = (mtime, 解析结果)
    // 文件 mtime 未变时直接返回缓存，跳过磁盘读取和 JSON 解析
    private struct FileCache {
        var mtime: Date
        var entries: [UsageEntry]
    }
    private var fileCache: [String: FileCache] = [:]

    init() {}

    // MARK: - 获取真实 Home 目录（绕过沙盒限制）

    /// 获取用户的真实 Home 目录（不受 App Sandbox 影响）
    /// 在沙盒中 FileManager.default.homeDirectoryForCurrentUser 和 ~ 都指向容器目录，
    /// 需要通过 getpwuid(getuid()) 读取 /etc/passwd 来获取真实 Home
    private func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir {
            return String(cString: homeDir)
        }
        // 备用：尝试从环境变量获取
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            return home
        }
        // 最后备用：使用标准 Home（沙盒下可能不正确）
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// 获取 Claude 数据目录的真实路径
    private func claudeDataPath(relativePath: String = ".claude/projects") -> String {
        return realHomeDirectory() + "/" + relativePath
    }

    // MARK: - 公共接口

    /// 加载使用数据条目
    /// - Parameters:
    ///   - dataPath: 数据目录路径，nil 表示使用默认 ~/.claude/projects（自动解析真实 Home）
    ///   - hoursBack: 往回查询的小时数，nil 表示查询所有数据
    ///   - since: 硬性起始时间（用于重置功能），与 hoursBack 取较晚值
    func loadUsageEntries(dataPath: String? = nil, hoursBack: Int? = nil, since: Date? = nil) -> [UsageEntry] {
        let expandedPath: String
        if let path = dataPath {
            // 显式传入路径时，先尝试 ~ 展开，再使用真实 Home
            if path.hasPrefix("~/") {
                expandedPath = realHomeDirectory() + path.dropFirst(1)
            } else {
                expandedPath = path
            }
        } else {
            expandedPath = claudeDataPath()
        }

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: expandedPath) else {
            logger.warning("数据目录不存在: \(expandedPath)")
            return []
        }

        let hoursBackDate: Date? = hoursBack.map { Date().addingTimeInterval(-Double($0) * 3600) }
        let cutoffDate: Date? = [hoursBackDate, since].compactMap { $0 }.max()

        // 递归查找所有 .jsonl 文件
        let jsonlFiles = findJsonlFiles(in: expandedPath, fileManager: fileManager)
        guard !jsonlFiles.isEmpty else {
            logger.info("未找到 .jsonl 文件，目录: \(expandedPath)")
            return []
        }

        var seenHashes = Set<String>()
        var allEntries: [UsageEntry] = []

        for filePath in jsonlFiles {
            let entries = parseFile(at: filePath, cutoffDate: cutoffDate, seenHashes: &seenHashes)
            allEntries.append(contentsOf: entries)
        }

        let sorted = allEntries.sorted { $0.timestamp < $1.timestamp }
        logger.info("已加载 \(sorted.count) 条记录（来自 \(jsonlFiles.count) 个文件）")
        return sorted
    }

    /// 获取聚合统计信息
    func getStatistics(hoursBack: Int? = nil, since: Date? = nil) -> UsageStatistics {
        UsageStatistics(entries: loadUsageEntries(hoursBack: hoursBack, since: since))
    }

    /// 一次文件扫描产出所有聚合所需的原始分组，供 MonitoringViewModel 使用
    struct AllData: Sendable {
        let allEntries: [UsageEntry]
        let todayEntries: [UsageEntry]
        let projectEntries: [String: [UsageEntry]]
        let dailyEntries: [Date: [UsageEntry]]
    }

    func loadAllData(since: Date? = nil, daysBack: Int = 30) -> AllData {
        let expandedPath = BookmarkManager.shared.resolvedPath() ?? claudeDataPath()
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: expandedPath) else {
            logger.warning("数据目录不存在: \(expandedPath)")
            return AllData(allEntries: [], todayEntries: [], projectEntries: [:], dailyEntries: [:])
        }

        let jsonlFiles = findJsonlFiles(in: expandedPath, fileManager: fileManager)
        guard !jsonlFiles.isEmpty else {
            return AllData(allEntries: [], todayEntries: [], projectEntries: [:], dailyEntries: [:])
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let todayCutoff = startOfToday
        let dailyCutoff = calendar.date(byAdding: .day, value: -daysBack, to: startOfToday)
            ?? now.addingTimeInterval(-Double(daysBack) * 86400)
        // 提前跳过条目的截止时间：
        // - since 有值时取 min(since, dailyCutoff)，因为 allEntries 需要 since 之后的全量数据
        // - since 为 nil 时只用 dailyCutoff 做提前跳过（allEntries 需要全量历史，不能用 dailyCutoff 截断）
        let overallCutoff: Date? = since.map { min($0, dailyCutoff) }

        var seenHashes = Set<String>()
        var allEntries: [UsageEntry] = []
        var todayEntries: [UsageEntry] = []
        var projectEntries: [String: [UsageEntry]] = [:]
        var dailyEntries: [Date: [UsageEntry]] = [:]

        for filePath in jsonlFiles {
            let dirPath = (filePath as NSString).deletingLastPathComponent
            let projectName = (dirPath as NSString).lastPathComponent

            // rawEntriesForFile 带 mtime 缓存，返回文件完整条目（无时间过滤）
            let fileEntries = rawEntriesForFile(at: filePath, seenHashes: &seenHashes)

            for entry in fileEntries {
                // 按项目：全量历史，与原 getProjectData(cutoffDate: nil) 行为一致
                projectEntries[projectName, default: []].append(entry)

                // since 有值时提前跳过绝对不需要的条目（性能优化，不影响正确性）
                if let cutoff = overallCutoff, entry.timestamp < cutoff { continue }

                // 全量（受 since 过滤）
                if since == nil || entry.timestamp >= since! {
                    allEntries.append(entry)
                }
                // 最近 24h
                if entry.timestamp >= todayCutoff {
                    todayEntries.append(entry)
                }
                // 按天（仅最近 daysBack 天）
                if entry.timestamp >= dailyCutoff {
                    let comps = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
                    if let dayDate = calendar.date(from: comps) {
                        dailyEntries[dayDate, default: []].append(entry)
                    }
                }
            }
        }

        allEntries.sort { $0.timestamp < $1.timestamp }
        logger.info("loadAllData: \(allEntries.count) 条记录（来自 \(jsonlFiles.count) 个文件）")
        return AllData(
            allEntries: allEntries,
            todayEntries: todayEntries,
            projectEntries: projectEntries,
            dailyEntries: dailyEntries
        )
    }

    /// 按小时分组统计
    func getHourlyData(hoursBack: Int = 24) -> [Date: UsageStatistics] {
        let entries = loadUsageEntries(hoursBack: hoursBack)
        let calendar = Calendar.current
        var grouped: [Date: [UsageEntry]] = [:]

        for entry in entries {
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: entry.timestamp)
            guard let hourDate = calendar.date(from: comps) else { continue }
            grouped[hourDate, default: []].append(entry)
        }

        return grouped.mapValues { UsageStatistics(entries: $0) }
    }

    /// 按天分组统计（最近 N 天）
    func getDailyData(daysBack: Int = 30, since: Date? = nil) -> [Date: UsageStatistics] {
        let calendar = Calendar.current
        // 以 daysBack 天前当天凌晨为起始，避免跨天边界问题
        let startOfToday = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: startOfToday) ?? Date().addingTimeInterval(-Double(daysBack) * 86400)
        let effectiveSince = [startDate, since].compactMap { $0 }.max()

        let entries = loadUsageEntries(since: effectiveSince)
        var grouped: [Date: [UsageEntry]] = [:]

        for entry in entries {
            let comps = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
            guard let dayDate = calendar.date(from: comps) else { continue }
            grouped[dayDate, default: []].append(entry)
        }

        return grouped.mapValues { UsageStatistics(entries: $0) }
    }

    /// 按项目（文件所在目录名）分组统计
    func getProjectData(dataPath: String? = nil) -> [String: UsageStatistics] {
        let expandedPath: String
        if let path = dataPath {
            if path.hasPrefix("~/") {
                expandedPath = realHomeDirectory() + path.dropFirst(1)
            } else {
                expandedPath = path
            }
        } else {
            expandedPath = claudeDataPath()
        }

        let fileManager = FileManager.default
        let jsonlFiles = findJsonlFiles(in: expandedPath, fileManager: fileManager)
        var seenHashes = Set<String>()
        var projectEntries: [String: [UsageEntry]] = [:]

        for filePath in jsonlFiles {
            // 取文件所在目录名作为项目名
            let dirPath = (filePath as NSString).deletingLastPathComponent
            let projectName = (dirPath as NSString).lastPathComponent

            let entries = parseFile(at: filePath, cutoffDate: nil, seenHashes: &seenHashes)
            if !entries.isEmpty {
                projectEntries[projectName, default: []].append(contentsOf: entries)
            }
        }

        return projectEntries.mapValues { UsageStatistics(entries: $0) }
    }

    // MARK: - 私有方法

    /// 递归查找目录下所有 .jsonl 文件
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

    /// 读取并解析单个 JSONL 文件，带 mtime 缓存（不做时间过滤，存储完整条目）
    /// 文件 mtime 未变时直接返回缓存，同时将缓存条目的 hash 插入 seenHashes 维持去重正确性
    private func rawEntriesForFile(at filePath: String, seenHashes: inout Set<String>) -> [UsageEntry] {
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let mtime = attrs?[.modificationDate] as? Date

        // 只对"冷文件"（超过 60 秒未修改）使用缓存
        // 活跃文件（Claude 正在写入）mtime 精度仅 1 秒，同一秒内追加的新条目会被缓存遮蔽
        let isStale = mtime.map { Date().timeIntervalSince($0) > 60 } ?? false
        if isStale, let mtime, let cached = fileCache[filePath], cached.mtime == mtime {
            for entry in cached.entries {
                let hash = "\(entry.messageId):\(entry.requestId)"
                if !entry.messageId.isEmpty && !entry.requestId.isEmpty {
                    seenHashes.insert(hash)
                }
            }
            return cached.entries
        }

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            logger.warning("无法读取文件: \(filePath)")
            return []
        }

        var entries: [UsageEntry] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            guard let timestampStr = json["timestamp"] as? String,
                  let timestamp = parseTimestamp(timestampStr) else {
                continue
            }

            let tokens = extractTokens(from: json)
            guard tokens.input > 0 || tokens.output > 0 || tokens.cacheRead > 0 || tokens.cacheCreate > 0 else {
                continue
            }

            let messageId = extractMessageId(from: json)
            let requestId = (json["request_id"] as? String) ?? (json["requestId"] as? String) ?? ""
            let hash = "\(messageId):\(requestId)"
            if !messageId.isEmpty && !requestId.isEmpty {
                if seenHashes.contains(hash) { continue }
                seenHashes.insert(hash)
            }

            let model = extractModel(from: json)
            let costUsd = calculateCost(from: json, model: model, tokens: tokens)

            entries.append(UsageEntry(
                id: hash.isEmpty ? UUID().uuidString : hash,
                timestamp: timestamp,
                inputTokens: tokens.input,
                outputTokens: tokens.output,
                cacheCreationTokens: tokens.cacheCreate,
                cacheReadTokens: tokens.cacheRead,
                costUsd: costUsd,
                model: model,
                messageId: messageId,
                requestId: requestId
            ))
        }

        if let mtime {
            fileCache[filePath] = FileCache(mtime: mtime, entries: entries)
        }
        return entries
    }

    /// 解析单个 JSONL 文件（带时间过滤，供旧接口 loadUsageEntries 使用）
    private func parseFile(at filePath: String, cutoffDate: Date?, seenHashes: inout Set<String>) -> [UsageEntry] {
        let all = rawEntriesForFile(at: filePath, seenHashes: &seenHashes)
        guard let cutoff = cutoffDate else { return all }
        return all.filter { $0.timestamp >= cutoff }
    }

    // MARK: - 字段提取辅助

    private typealias TokenCounts = (input: Int, output: Int, cacheRead: Int, cacheCreate: Int)

    /// 提取 token 数量
    /// 与 Python TokenExtractor.extract_tokens() 保持一致：
    /// - type=="assistant" 时：优先 message.usage > usage > 顶层
    /// - 其他类型：优先 usage > message.usage > 顶层
    private func extractTokens(from json: [String: Any]) -> TokenCounts {
        let isAssistant = (json["type"] as? String) == "assistant"
        let message = json["message"] as? [String: Any]
        let messageUsage = message?["usage"] as? [String: Any]
        let topUsage = json["usage"] as? [String: Any]

        var sources: [[String: Any]] = []

        if isAssistant {
            // assistant 类型：优先 message.usage > usage > 顶层
            if let mu = messageUsage { sources.append(mu) }
            if let tu = topUsage { sources.append(tu) }
            sources.append(json)
        } else {
            // 其他类型：优先 usage > message.usage > 顶层
            if let tu = topUsage { sources.append(tu) }
            if let mu = messageUsage { sources.append(mu) }
            sources.append(json)
        }

        for source in sources {
            let input = intValue(source, keys: ["input_tokens", "inputTokens", "prompt_tokens"])
            let output = intValue(source, keys: ["output_tokens", "outputTokens", "completion_tokens"])

            if input > 0 || output > 0 {
                let cacheCreate = intValue(source, keys: ["cache_creation_tokens", "cache_creation_input_tokens", "cacheCreationInputTokens"])
                let cacheRead = intValue(source, keys: ["cache_read_input_tokens", "cache_read_tokens", "cacheReadInputTokens"])
                return (input: input, output: output, cacheRead: cacheRead, cacheCreate: cacheCreate)
            }
        }

        return (0, 0, 0, 0)
    }

    /// 从字典中按优先级读取 Int 值
    private func intValue(_ dict: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let v = dict[key] as? Int, v > 0 { return v }
            if let v = dict[key] as? Double, v > 0 { return Int(v) }
        }
        return 0
    }

    private func extractMessageId(from json: [String: Any]) -> String {
        if let mid = json["message_id"] as? String { return mid }
        if let msg = json["message"] as? [String: Any], let id = msg["id"] as? String { return id }
        return ""
    }

    /// 提取模型名称（与 Python DataConverter.extract_model_name 保持一致）
    private func extractModel(from json: [String: Any]) -> String {
        let message = json["message"] as? [String: Any]
        let usage = json["usage"] as? [String: Any]
        let request = json["request"] as? [String: Any]

        let candidates: [String?] = [
            message?["model"] as? String,
            json["model"] as? String,
            json["Model"] as? String,
            usage?["model"] as? String,
            request?["model"] as? String,
        ]

        for candidate in candidates {
            if let model = candidate, !model.isEmpty {
                return model
            }
        }
        return "unknown"
    }

    /// 计算成本（与 Python calculate_cost_for_entry AUTO 模式保持一致）
    /// AUTO 模式：优先用 JSONL 中的 cost/cost_usd 字段，如果没有则按定价模型计算
    private func calculateCost(from json: [String: Any], model: String, tokens: TokenCounts) -> Double {
        // 优先使用 JSONL 中记录的成本
        if let cost = json["cost_usd"] as? Double, cost > 0 { return cost }
        if let cost = json["cost"] as? Double, cost > 0 { return cost }

        // 没有记录成本时，按模型定价计算
        let pricing = ModelPricing.forModel(model)
        return pricing.calculateCost(
            input: tokens.input,
            output: tokens.output,
            cacheCreation: tokens.cacheCreate,
            cacheRead: tokens.cacheRead
        )
    }

    /// 解析 ISO8601 时间戳（支持有无毫秒）
    private func parseTimestamp(_ str: String) -> Date? {
        var normalized = str
        // 将 Z 结尾转换为 +00:00（与 Python TimestampProcessor 一致）
        if normalized.hasSuffix("Z") {
            normalized = String(normalized.dropLast()) + "+00:00"
        }

        if let date = TokenDataReader.isoWithFractional.date(from: normalized) { return date }
        if let date = TokenDataReader.isoBasic.date(from: normalized) { return date }

        for formatter in TokenDataReader.fallbackDateFormatters {
            if let date = formatter.date(from: str) { return date }
        }

        return nil
    }
}
