import Foundation
import os.log

// MARK: - 数据模型（与实际 JSONL 格式对应）

/// 从 JSONL 文件解析出的原始使用记录
struct UsageEntry: Identifiable, Sendable {
    let id: String          // message_id + request_id 组合
    let timestamp: Date
    let sessionId: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUsd: Double
    let model: String
    let messageId: String
    let requestId: String
    let mcpServers: [String]
    let skills: [String]
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
/// 官方定价源：https://platform.claude.com/docs/en/about-claude/pricing
private struct ModelPricing {
    let input: Double
    let output: Double
    let cacheCreation: Double
    let cacheRead: Double

    /// 定价配置表（按匹配优先级排序，越靠前越优先）
    /// 格式：(关键字, 是否前缀匹配, 定价)
    /// 设计为可扩展：添加新模型只需在此数组中添加一行
    private static let pricingConfigs: [(keyword: String, isPrefix: Bool, pricing: ModelPricing)] = [
        // Mythos 系列（Project Glasswing 限定）
        ("mythos", false, ModelPricing(input: 10.0, output: 50.0, cacheCreation: 12.50, cacheRead: 1.0)),

        // Fable 5
        ("fable", false, ModelPricing(input: 10.0, output: 50.0, cacheCreation: 12.50, cacheRead: 1.0)),

        // Opus 4.5/4.6/4.7/4.8（新版定价）
        ("opus-4-5", true, ModelPricing(input: 5.0, output: 25.0, cacheCreation: 6.25, cacheRead: 0.5)),
        ("opus-4-6", true, ModelPricing(input: 5.0, output: 25.0, cacheCreation: 6.25, cacheRead: 0.5)),
        ("opus-4-7", true, ModelPricing(input: 5.0, output: 25.0, cacheCreation: 6.25, cacheRead: 0.5)),
        ("opus-4-8", true, ModelPricing(input: 5.0, output: 25.0, cacheCreation: 6.25, cacheRead: 0.5)),
        // Opus 4/4.1（旧版，已 deprecated）
        ("opus", false, ModelPricing(input: 15.0, output: 75.0, cacheCreation: 18.75, cacheRead: 1.5)),

        // Haiku 4.5
        ("haiku-4-5", true, ModelPricing(input: 1.0, output: 5.0, cacheCreation: 1.25, cacheRead: 0.1)),
        // Haiku 3.5（旧版）
        ("haiku", false, ModelPricing(input: 0.8, output: 4.0, cacheCreation: 1.0, cacheRead: 0.08)),

        // Sonnet 4.x（默认兜底）
        ("sonnet", false, ModelPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.3)),
    ]

    /// 根据模型名称获取定价
    /// 新增模型支持：在 pricingConfigs 数组中添加配置即可
    static func forModel(_ model: String) -> ModelPricing {
        let lower = model.lowercased()

        for config in pricingConfigs {
            if config.isPrefix {
                // 前缀匹配（用于版本号区分，如 opus-4-8 优先于 opus）
                if lower.contains(config.keyword) {
                    return config.pricing
                }
            } else {
                // 包含匹配（通用名称匹配）
                if lower.contains(config.keyword) {
                    return config.pricing
                }
            }
        }

        // 默认使用 Sonnet 定价（最保守估计）
        return ModelPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.3)
    }

    /// 获取默认定价（用于无法识别模型时）
    static var `default`: ModelPricing {
        ModelPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.3)
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
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "tokenreader")

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
        var configSignature: String
        var entries: [UsageEntry]
    }
    private var fileCache: [String: FileCache] = [:]

    private struct UserToolConfig {
        let mcpServers: Set<String>
        let skills: Set<String>
        let hasMcpWhitelist: Bool
        let hasSkillWhitelist: Bool

        var signature: String {
            let mcp = mcpServers.sorted().joined(separator: ",")
            let skill = skills.sorted().joined(separator: ",")
            return "mcp:\(hasMcpWhitelist):\(mcp)|skills:\(hasSkillWhitelist):\(skill)"
        }

        func isUserMcp(_ server: String) -> Bool {
            !hasMcpWhitelist || mcpServers.contains(server)
        }

        func normalizedSkill(_ skill: String) -> String {
            skill.split(separator: ":").last.map(String.init) ?? skill
        }

        func isUserSkill(_ skill: String) -> Bool {
            !hasSkillWhitelist || skills.contains(normalizedSkill(skill))
        }
    }

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

    private func loadUserToolConfig() -> UserToolConfig {
        let home = realHomeDirectory()
        let fileManager = FileManager.default
        var mcpServers = Set<String>()
        var skills = Set<String>()
        var hasMcpWhitelist = false
        var hasSkillWhitelist = false

        let claudeConfigPath = (home as NSString).appendingPathComponent(".claude.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: claudeConfigPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            hasMcpWhitelist = true
            collectMcpServers(from: json["mcpServers"], into: &mcpServers)
            if let projects = json["projects"] as? [String: Any] {
                for projectValue in projects.values {
                    guard let project = projectValue as? [String: Any] else { continue }
                    collectMcpServers(from: project["mcpServers"], into: &mcpServers)
                }
            }
        }

        let skillsPath = (home as NSString).appendingPathComponent(".claude/skills")
        if let names = try? fileManager.contentsOfDirectory(atPath: skillsPath) {
            hasSkillWhitelist = true
            for name in names {
                let path = (skillsPath as NSString).appendingPathComponent(name)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                    skills.insert(name)
                }
            }
        }

        return UserToolConfig(
            mcpServers: mcpServers,
            skills: skills,
            hasMcpWhitelist: hasMcpWhitelist,
            hasSkillWhitelist: hasSkillWhitelist
        )
    }

    private func collectMcpServers(from value: Any?, into servers: inout Set<String>) {
        guard let dict = value as? [String: Any] else { return }
        for key in dict.keys where !key.isEmpty {
            servers.insert(key)
        }
    }

    private func installedMcpCount(from entries: [UsageEntry], config: UserToolConfig) -> Int {
        if config.hasMcpWhitelist {
            return config.mcpServers.count
        }
        return Set(entries.flatMap(\.mcpServers)).count
    }

    private func installedSkillCount(from entries: [UsageEntry], config: UserToolConfig) -> Int {
        if config.hasSkillWhitelist {
            return config.skills.count
        }
        return Set(entries.flatMap(\.skills)).count
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
        let toolConfig = loadUserToolConfig()

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
            let entries = parseFile(at: filePath, cutoffDate: cutoffDate, seenHashes: &seenHashes, config: toolConfig)
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
        let installedMcpServers: Int
        let installedSkills: Int
    }

    func loadAllData(since: Date? = nil, daysBack: Int = 30) -> AllData {
        let expandedPath = BookmarkManager.shared.resolvedPath() ?? claudeDataPath()
        let fileManager = FileManager.default
        let toolConfig = loadUserToolConfig()

        guard fileManager.fileExists(atPath: expandedPath) else {
            logger.warning("数据目录不存在: \(expandedPath)")
            return AllData(
                allEntries: [],
                todayEntries: [],
                projectEntries: [:],
                dailyEntries: [:],
                installedMcpServers: installedMcpCount(from: [], config: toolConfig),
                installedSkills: installedSkillCount(from: [], config: toolConfig)
            )
        }

        let jsonlFiles = findJsonlFiles(in: expandedPath, fileManager: fileManager)
        guard !jsonlFiles.isEmpty else {
            return AllData(
                allEntries: [],
                todayEntries: [],
                projectEntries: [:],
                dailyEntries: [:],
                installedMcpServers: installedMcpCount(from: [], config: toolConfig),
                installedSkills: installedSkillCount(from: [], config: toolConfig)
            )
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
            let fileEntries = rawEntriesForFile(at: filePath, seenHashes: &seenHashes, config: toolConfig)

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
            dailyEntries: dailyEntries,
            installedMcpServers: installedMcpCount(from: allEntries, config: toolConfig),
            installedSkills: installedSkillCount(from: allEntries, config: toolConfig)
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
        let toolConfig = loadUserToolConfig()
        var seenHashes = Set<String>()
        var projectEntries: [String: [UsageEntry]] = [:]

        for filePath in jsonlFiles {
            // 取文件所在目录名作为项目名
            let dirPath = (filePath as NSString).deletingLastPathComponent
            let projectName = (dirPath as NSString).lastPathComponent

            let entries = parseFile(at: filePath, cutoffDate: nil, seenHashes: &seenHashes, config: toolConfig)
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
    private func rawEntriesForFile(at filePath: String, seenHashes: inout Set<String>, config: UserToolConfig) -> [UsageEntry] {
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let mtime = attrs?[.modificationDate] as? Date

        // 只对"冷文件"（超过 60 秒未修改）使用缓存
        // 活跃文件（Claude 正在写入）mtime 精度仅 1 秒，同一秒内追加的新条目会被缓存遮蔽
        let isStale = mtime.map { Date().timeIntervalSince($0) > 60 } ?? false
        if isStale,
           let mtime,
           let cached = fileCache[filePath],
           cached.mtime == mtime,
           cached.configSignature == config.signature {
            for entry in cached.entries {
                if !entry.id.isEmpty {
                    seenHashes.insert(entry.id)
                }
            }
            return cached.entries
        }

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            logger.warning("无法读取文件: \(filePath)")
            return []
        }

        var entriesByKey: [String: UsageEntry] = [:]
        var orderedKeys: [String] = []
        var localKeys = Set<String>()
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
            let toolUsage = extractToolUsage(from: json, config: config)
            let hasTokens = tokens.input > 0 || tokens.output > 0 || tokens.cacheRead > 0 || tokens.cacheCreate > 0
            let hasToolUsage = !toolUsage.mcpServers.isEmpty || !toolUsage.skills.isEmpty
            guard hasTokens || hasToolUsage else {
                continue
            }

            let messageId = extractMessageId(from: json)
            let requestId = (json["request_id"] as? String) ?? (json["requestId"] as? String) ?? ""
            let uuid = (json["uuid"] as? String) ?? ""
            let entryKey = !messageId.isEmpty ? messageId : (!uuid.isEmpty ? uuid : (!requestId.isEmpty ? requestId : UUID().uuidString))

            if !localKeys.contains(entryKey), seenHashes.contains(entryKey) {
                continue
            }

            let isUserCommand = (json["type"] as? String) == "user"
            let model = isUserCommand ? "" : extractModel(from: json)
            let costUsd = hasTokens ? calculateCost(from: json, model: model, tokens: tokens) : 0

            let entry = UsageEntry(
                id: entryKey,
                timestamp: timestamp,
                sessionId: extractSessionId(from: json),
                inputTokens: tokens.input,
                outputTokens: tokens.output,
                cacheCreationTokens: tokens.cacheCreate,
                cacheReadTokens: tokens.cacheRead,
                costUsd: costUsd,
                model: model,
                messageId: messageId,
                requestId: requestId,
                mcpServers: toolUsage.mcpServers,
                skills: toolUsage.skills
            )

            if let existing = entriesByKey[entryKey] {
                entriesByKey[entryKey] = mergeUsageEntries(existing, entry)
            } else {
                entriesByKey[entryKey] = entry
                orderedKeys.append(entryKey)
            }
            localKeys.insert(entryKey)
        }

        for key in localKeys {
            seenHashes.insert(key)
        }

        let entries = orderedKeys.compactMap { entriesByKey[$0] }
        if let mtime {
            fileCache[filePath] = FileCache(mtime: mtime, configSignature: config.signature, entries: entries)
        }
        return entries
    }

    /// 解析单个 JSONL 文件（带时间过滤，供旧接口 loadUsageEntries 使用）
    private func parseFile(at filePath: String, cutoffDate: Date?, seenHashes: inout Set<String>, config: UserToolConfig) -> [UsageEntry] {
        let all = rawEntriesForFile(at: filePath, seenHashes: &seenHashes, config: config)
        guard let cutoff = cutoffDate else { return all }
        return all.filter { $0.timestamp >= cutoff }
    }

    // MARK: - 字段提取辅助

    private typealias TokenCounts = (input: Int, output: Int, cacheRead: Int, cacheCreate: Int)
    private typealias ToolUsage = (mcpServers: [String], skills: [String])

    private func mergeUsageEntries(_ existing: UsageEntry, _ incoming: UsageEntry) -> UsageEntry {
        let existingHasTokens = hasTokenUsage(existing)
        let incomingHasTokens = hasTokenUsage(incoming)
        let tokenSource = existingHasTokens || !incomingHasTokens ? existing : incoming
        let timestamp = min(existing.timestamp, incoming.timestamp)
        let model: String
        if tokenSource.model.isEmpty || tokenSource.model == "unknown" {
            model = incoming.model.isEmpty ? existing.model : incoming.model
        } else {
            model = tokenSource.model
        }

        return UsageEntry(
            id: existing.id,
            timestamp: timestamp,
            sessionId: existing.sessionId.isEmpty ? incoming.sessionId : existing.sessionId,
            inputTokens: tokenSource.inputTokens,
            outputTokens: tokenSource.outputTokens,
            cacheCreationTokens: tokenSource.cacheCreationTokens,
            cacheReadTokens: tokenSource.cacheReadTokens,
            costUsd: tokenSource.costUsd,
            model: model,
            messageId: existing.messageId.isEmpty ? incoming.messageId : existing.messageId,
            requestId: existing.requestId.isEmpty ? incoming.requestId : existing.requestId,
            mcpServers: existing.mcpServers + incoming.mcpServers,
            skills: existing.skills + incoming.skills
        )
    }

    private func hasTokenUsage(_ entry: UsageEntry) -> Bool {
        entry.inputTokens > 0 || entry.outputTokens > 0 || entry.cacheReadTokens > 0 || entry.cacheCreationTokens > 0
    }

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

    private func extractSessionId(from json: [String: Any]) -> String {
        if let sessionId = json["sessionId"] as? String { return sessionId }
        if let sessionId = json["session_id"] as? String { return sessionId }
        if let sessionId = json["session"] as? String { return sessionId }
        return ""
    }

    private func extractToolUsage(from json: [String: Any], config: UserToolConfig) -> ToolUsage {
        var mcpServers: [String] = []
        var skills: [String] = []

        if (json["type"] as? String) == "user",
           let text = extractMessageContentText(from: json),
           let rawCommand = extractTagContent(from: text, tag: "command-name") {
            var skill = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            while skill.hasPrefix("/") {
                skill.removeFirst()
            }
            if !skill.isEmpty, config.isUserSkill(skill) {
                skills.append(config.normalizedSkill(skill))
            }
        }

        let message = json["message"] as? [String: Any]
        let content = (message?["content"] as? [Any]) ?? (json["content"] as? [Any]) ?? []
        for item in content {
            guard let block = item as? [String: Any],
                  (block["type"] as? String) == "tool_use",
                  let name = block["name"] as? String else {
                continue
            }

            if name.hasPrefix("mcp__") {
                let components = name.components(separatedBy: "__")
                guard components.count >= 2 else { continue }
                let server = components[1]
                if !server.isEmpty, config.isUserMcp(server) {
                    mcpServers.append(server)
                }
            } else if name == "Skill",
                      let input = block["input"] as? [String: Any],
                      let skill = input["skill"] as? String,
                      !skill.isEmpty,
                      config.isUserSkill(skill) {
                skills.append(config.normalizedSkill(skill))
            }
        }

        return (mcpServers: mcpServers, skills: skills)
    }

    private func extractMessageContentText(from json: [String: Any]) -> String? {
        let message = json["message"] as? [String: Any]

        if let text = message?["content"] as? String {
            return text
        }
        if let text = json["content"] as? String {
            return text
        }

        let content = (message?["content"] as? [Any]) ?? (json["content"] as? [Any]) ?? []
        let parts = content.compactMap { item -> String? in
            guard let block = item as? [String: Any] else { return nil }
            return block["text"] as? String
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func extractTagContent(from text: String, tag: String) -> String? {
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        guard let startRange = text.range(of: open) else { return nil }
        let rest = text[startRange.upperBound...]
        guard let endRange = rest.range(of: close) else { return nil }
        return String(rest[..<endRange.lowerBound])
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
