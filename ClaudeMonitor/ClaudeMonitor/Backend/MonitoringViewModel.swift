import Foundation
import Observation
import os.log
import SwiftUI

// MARK: - 新的 TokenScope 风格数据结构

struct Metrics {
    var totalTokens: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheTokens: Int = 0
    var cost: Double = 0
    var mcpCalls: Int = 0
    var skillCalls: Int = 0
    var requests: Int = 0
    var sessions: Int = 0
    var deltaTokens: Double = 0 // pct
    var servers: Int = 0
    var skills: Int = 0
}

struct ModelStat: Identifiable {
    var id: String { name }
    var name: String
    var tokens: Int = 0
    var cost: Double = 0
}

struct NamedCount: Identifiable {
    var id: String { name }
    var name: String
    var count: Int
}

struct SeriesPoint: Identifiable {
    var id: String { full }
    var label: String
    var full: String
    var input: Int
    var cache: Int
    var output: Int
}

struct HeatDay: Identifiable {
    var id: Date { date }
    var date: Date
    var tokens: Int
    var level: Int
}

struct PeriodReport {
    var metrics: Metrics = Metrics()
    var series: [SeriesPoint] = []
    var models: [ModelStat] = []
    var projects: [NamedCount] = []
    var mcp: [NamedCount] = []
    var skills: [NamedCount] = []
    var reqTrend: [Double] = []
    var costTrend: [Double] = []
    
    static var empty: PeriodReport { PeriodReport() }
}

struct Dashboard {
    var day: PeriodReport = .empty
    var week: PeriodReport = .empty
    var month: PeriodReport = .empty
    var heatmap: [HeatDay] = []
    
    static var empty: Dashboard { Dashboard() }
}

// MARK: - 监控数据 Model

/// 限额数据来源（按优先级）
enum LimitSource {
    case officialApi    // OAuth usage API（Claude Code /usage 同源，最准确）
    case daemonFile     // claude-code-usage-monitor 守护进程 state 文件
    case localEstimate  // 本地 JSONL P90 估算（兜底）
    case none
}

struct MonitoringData {
    var dashboard: Dashboard = .empty
    var lastUpdated: Date = Date()
    var v4State: V4StateProtocol? = nil
    var limitSource: LimitSource = .none

    static var empty: MonitoringData { MonitoringData() }
}

// MARK: - Token 速率（每秒增量）

struct TokenRate {
    var inputPerSec: Double = 0
    var outputPerSec: Double = 0
    var hasActivity: Bool { inputPerSec > 0 || outputPerSec > 0 }
}

// MARK: - 后台加载结果

private struct LoadResult: Sendable {
    let allEntries: [UsageEntry]
    let todayEntries: [UsageEntry]
    let projectEntries: [String: [UsageEntry]]
    let dailyEntries: [Date: [UsageEntry]]
    let installedMcpServers: Int
    let installedSkills: Int
}

// MARK: - 监控视图模型

@Observable
@MainActor
final class MonitoringViewModel {
    var monitoringData: MonitoringData = .empty
    var tokenRate: TokenRate = TokenRate()
    var burnRatePerMin: Double = 0 // 最近 60 分钟窗口燃烧率 (tokens/min)
    var isLoading = false
    var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "viewmodel")
    private let tokenReader = TokenDataReader()
    private let stateReader = StateProtocolReader()
    private let oauthReader = OAuthUsageReader()
    @ObservationIgnored nonisolated(unsafe) private var autoRefreshTask: Task<Void, Never>?

    private var lastSampleInput: Int = 0
    private var lastSampleOutput: Int = 0
    private var lastSampleTime: Date = Date()
    private var isFirstLoad = true

    private var inputHistory: [Double] = []
    private var outputHistory: [Double] = []
    private let historySize = 5

    init() {
        startAutoRefresh()
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    func refreshData() {
        Task { await loadData() }
    }

    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let reader = tokenReader
        let stateR = stateReader
        let oauthR = oauthReader

        // 限额数据源优先级：OAuth 官方 API → 守护进程 state 文件 → 本地 P90 估算（updateMonitoringData 内兜底）
        let (result, state, source) = await Task.detached(priority: .userInitiated) { () -> (LoadResult, V4StateProtocol?, LimitSource) in
            var v4State = await oauthR.readState()
            var source: LimitSource = v4State != nil ? .officialApi : .none
            if v4State == nil {
                v4State = await stateR.readState()
                if v4State != nil { source = .daemonFile }
            }
            // 加载约半年数据以便生成 Tokenscope 风格热力图
            let allData = reader.loadAllData(daysBack: 190)
            return (
                LoadResult(
                    allEntries: allData.allEntries,
                    todayEntries: allData.todayEntries,
                    projectEntries: allData.projectEntries,
                    dailyEntries: allData.dailyEntries,
                    installedMcpServers: allData.installedMcpServers,
                    installedSkills: allData.installedSkills
                ),
                v4State,
                source
            )
        }.value

        updateMonitoringData(from: result, v4State: state, source: source)

        if result.allEntries.isEmpty && state == nil {
            errorMessage = "未找到数据，请检查本地用量数据目录访问权限"
        }

        isLoading = false
    }

    private func updateMonitoringData(from result: LoadResult, v4State: V4StateProtocol?, source: LimitSource) {
        let now = Date()
        let calendar = Calendar.current
        
        // 计算速率
        let totalInput = result.allEntries.reduce(0) { $0 + $1.inputTokens + $1.cacheReadTokens }
        let totalOutput = result.allEntries.reduce(0) { $0 + $1.outputTokens }
        
        if !isFirstLoad {
            let elapsed = now.timeIntervalSince(lastSampleTime)
            if elapsed > 0 {
                let rawInputRate = Double(max(0, totalInput - lastSampleInput)) / elapsed
                let rawOutputRate = Double(max(0, totalOutput - lastSampleOutput)) / elapsed

                inputHistory.append(rawInputRate)
                outputHistory.append(rawOutputRate)
                if inputHistory.count > historySize { inputHistory.removeFirst() }
                if outputHistory.count > historySize { outputHistory.removeFirst() }

                let inputCount = Double(inputHistory.count)
                let outputCount = Double(outputHistory.count)
                tokenRate = TokenRate(
                    inputPerSec: inputCount > 0 ? inputHistory.reduce(0, +) / inputCount : 0,
                    outputPerSec: outputCount > 0 ? outputHistory.reduce(0, +) / outputCount : 0
                )
            }
        } else {
            isFirstLoad = false
        }
        lastSampleInput = totalInput
        lastSampleOutput = totalOutput
        lastSampleTime = now

        // 燃烧率：最近 60 分钟 token 总量 / 60（同 Claude-Code-Usage-Monitor 算法）
        let hourAgo = now.addingTimeInterval(-3600)
        let recentTokens = result.allEntries
            .filter { $0.timestamp >= hourAgo }
            .reduce(0) { $0 + totalTokens(in: $1) }
        burnRatePerMin = Double(recentTokens) / 60.0

        // 构建 Dashboard
        var dashboard = Dashboard()
        let dayRange = periodRange(for: .day, now: now, calendar: calendar)
        let weekRange = periodRange(for: .week, now: now, calendar: calendar)
        let monthRange = periodRange(for: .month, now: now, calendar: calendar)

        dashboard.day = buildPeriodReport(
            entries: entries(in: result.allEntries, from: dayRange.currentStart, to: dayRange.currentEnd),
            previousEntries: entries(in: result.allEntries, from: dayRange.previousStart, to: dayRange.previousEnd),
            period: .day,
            now: now,
            installedMcpServers: result.installedMcpServers,
            installedSkills: result.installedSkills
        )
        dashboard.week = buildPeriodReport(
            entries: entries(in: result.allEntries, from: weekRange.currentStart, to: weekRange.currentEnd),
            previousEntries: entries(in: result.allEntries, from: weekRange.previousStart, to: weekRange.previousEnd),
            period: .week,
            now: now,
            installedMcpServers: result.installedMcpServers,
            installedSkills: result.installedSkills
        )
        dashboard.month = buildPeriodReport(
            entries: entries(in: result.allEntries, from: monthRange.currentStart, to: monthRange.currentEnd),
            previousEntries: entries(in: result.allEntries, from: monthRange.previousStart, to: monthRange.previousEnd),
            period: .month,
            now: now,
            installedMcpServers: result.installedMcpServers,
            installedSkills: result.installedSkills
        )

        // 构建 Heatmap
        var heatmapMap: [Date: Int] = [:]
        for entry in result.allEntries {
            let start = calendar.startOfDay(for: entry.timestamp)
            heatmapMap[start, default: 0] += entry.inputTokens + entry.cacheCreationTokens + entry.cacheReadTokens + entry.outputTokens
        }
        
        let startOfToday = calendar.startOfDay(for: now)
        let daysFromSunday = calendar.component(.weekday, from: startOfToday) - 1
        let heatmapStart = calendar.date(byAdding: .day, value: -(25 * 7 + daysFromSunday), to: startOfToday) ?? startOfToday
        var heatmap: [HeatDay] = []
        
        // 找出最大的 tokens 用于计算 level (0-4)
        let maxTokens = heatmapMap.values.max() ?? 1
        
        var cursor = heatmapStart
        while cursor <= startOfToday {
            let tokens = heatmapMap[cursor] ?? 0
            var level = 0
            if tokens > 0 {
                let ratio = Double(tokens) / Double(maxTokens)
                if ratio >= 0.75 { level = 4 }
                else if ratio >= 0.5 { level = 3 }
                else if ratio >= 0.25 { level = 2 }
                else { level = 1 }
            }
            heatmap.append(HeatDay(date: cursor, tokens: tokens, level: level))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? startOfToday.addingTimeInterval(1)
        }
        dashboard.heatmap = heatmap
        
        // Fallback: 官方 API 和守护进程都不可用时，使用本地 P90 估算
        let effectiveV4State: V4StateProtocol?
        let effectiveSource: LimitSource
        if let v4State = v4State {
            effectiveV4State = v4State
            effectiveSource = source
        } else {
            effectiveV4State = calculateLocalRateLimits(from: result.allEntries, now: now)
            effectiveSource = effectiveV4State != nil ? .localEstimate : .none
        }

        var updated = MonitoringData()
        updated.dashboard = dashboard
        updated.lastUpdated = now
        updated.v4State = effectiveV4State
        updated.limitSource = effectiveSource

        monitoringData = updated
    }
    
    private enum Period { case day, week, month }

    private typealias PeriodWindow = (currentStart: Date, currentEnd: Date, previousStart: Date, previousEnd: Date)

    private func entries(in entries: [UsageEntry], from start: Date, to end: Date) -> [UsageEntry] {
        entries.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    private func periodRange(for period: Period, now: Date, calendar: Calendar) -> PeriodWindow {
        let startOfToday = calendar.startOfDay(for: now)

        switch period {
        case .day:
            let next = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            let previous = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now.addingTimeInterval(-86400)
            return (startOfToday, next, previous, startOfToday)

        case .week:
            let daysFromMonday = (calendar.component(.weekday, from: startOfToday) + 5) % 7
            let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfToday) ?? startOfToday
            let next = calendar.date(byAdding: .day, value: 7, to: start) ?? now
            let previous = calendar.date(byAdding: .day, value: -7, to: start) ?? now.addingTimeInterval(-86400 * 7)
            return (start, next, previous, start)

        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? startOfToday
            let next = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            let previous = calendar.date(byAdding: .month, value: -1, to: start) ?? now.addingTimeInterval(-86400 * 30)
            return (start, next, previous, start)
        }
    }

    private func buildPeriodReport(
        entries: [UsageEntry],
        previousEntries: [UsageEntry],
        period: Period,
        now: Date,
        installedMcpServers: Int,
        installedSkills: Int
    ) -> PeriodReport {
        var report = PeriodReport()
        var metrics = Metrics()
        metrics.totalTokens = totalTokens(in: entries)
        metrics.inputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        metrics.outputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        metrics.cacheTokens = entries.reduce(0) { $0 + $1.cacheReadTokens + $1.cacheCreationTokens }
        metrics.cost = entries.reduce(0) { $0 + $1.costUsd }
        metrics.mcpCalls = entries.reduce(0) { $0 + $1.mcpServers.count }
        metrics.skillCalls = entries.reduce(0) { $0 + $1.skills.count }
        metrics.requests = entries.filter { !$0.model.isEmpty }.count
        metrics.sessions = Set(entries.map(\.sessionId).filter { !$0.isEmpty }).count
        metrics.deltaTokens = pctDelta(current: Double(metrics.totalTokens), previous: Double(totalTokens(in: previousEntries)))
        metrics.servers = installedMcpServers
        metrics.skills = installedSkills
        report.metrics = metrics
        
        // 聚合模型
        var modelDict: [String: (tokens: Int, cost: Double)] = [:]
        for entry in entries {
            guard !entry.model.isEmpty else { continue }
            let m = normalizeModelName(entry.model)
            let cur = modelDict[m] ?? (0, 0.0)
            modelDict[m] = (cur.tokens + totalTokens(in: entry), cur.cost + entry.costUsd)
        }
        var models = modelDict.map { k, v in ModelStat(name: k, tokens: v.tokens, cost: v.cost) }
        models.sort { $0.tokens > $1.tokens }
        report.models = models

        report.mcp = namedCounts(from: entries.flatMap(\.mcpServers))
        report.skills = namedCounts(from: entries.flatMap(\.skills))

        let calendar = Calendar.current
        let range = periodRange(for: period, now: now, calendar: calendar)
        var buckets = makeEmptyBuckets(for: period, start: range.currentStart, end: range.currentEnd, calendar: calendar)

        for entry in entries {
            guard let index = bucketIndex(for: entry.timestamp, period: period, start: range.currentStart, calendar: calendar),
                  buckets.indices.contains(index) else { continue }
            buckets[index].input += entry.inputTokens
            buckets[index].cache += entry.cacheReadTokens + entry.cacheCreationTokens
            buckets[index].output += entry.outputTokens
            buckets[index].cost += entry.costUsd
            if !entry.model.isEmpty {
                buckets[index].requests += 1
            }
        }

        report.series = buckets.map {
            SeriesPoint(label: $0.label, full: $0.full, input: $0.input, cache: $0.cache, output: $0.output)
        }
        report.costTrend = buckets.map { $0.cost }
        report.reqTrend = buckets.map { Double($0.requests) }
        
        return report
    }

    private typealias Bucket = (label: String, full: String, input: Int, cache: Int, output: Int, requests: Int, cost: Double)

    private func makeEmptyBuckets(for period: Period, start: Date, end: Date, calendar: Calendar) -> [Bucket] {
        switch period {
        case .day:
            return (0..<24).map { hour in
                let label = hour % 4 == 0 && hour != 0 ? String(format: "%02d", hour) : ""
                return (label, String(format: "%02d:00", hour), 0, 0, 0, 0, 0)
            }

        case .week:
            let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            return (0..<7).map { index in
                let date = calendar.date(byAdding: .day, value: index, to: start) ?? start
                let components = calendar.dateComponents([.month, .day], from: date)
                let full = "\(weekdays[index]) \(monthName(components.month ?? 1)) \(components.day ?? index + 1)"
                return (weekdays[index], full, 0, 0, 0, 0, 0)
            }

        case .month:
            let days = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 30)
            let month = calendar.component(.month, from: start)
            return (0..<days).map { index in
                let day = index + 1
                let label = index == 0 || day % 5 == 0 ? "\(day)" : ""
                return (label, "\(monthName(month)) \(day)", 0, 0, 0, 0, 0)
            }
        }
    }

    private func bucketIndex(for date: Date, period: Period, start: Date, calendar: Calendar) -> Int? {
        switch period {
        case .day:
            return calendar.component(.hour, from: date)
        case .week:
            let startOfDay = calendar.startOfDay(for: date)
            return calendar.dateComponents([.day], from: start, to: startOfDay).day
        case .month:
            return calendar.component(.day, from: date) - 1
        }
    }

    private func totalTokens(in entries: [UsageEntry]) -> Int {
        entries.reduce(0) { $0 + totalTokens(in: $1) }
    }

    private func totalTokens(in entry: UsageEntry) -> Int {
        entry.inputTokens + entry.outputTokens + entry.cacheReadTokens + entry.cacheCreationTokens
    }

    private func pctDelta(current: Double, previous: Double) -> Double {
        // 上期为 0 但本期有用量时按 +100% 处理（语义"新增"），避免误显示 0%
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return ((current - previous) / previous * 10_000).rounded() / 100
    }

    private func namedCounts(from names: [String]) -> [NamedCount] {
        var counts: [String: Int] = [:]
        for name in names where !name.isEmpty {
            counts[name, default: 0] += 1
        }
        return counts.map { NamedCount(name: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    private func normalizeModelName(_ model: String) -> String {
        guard let lastDash = model.lastIndex(of: "-") else { return model }
        let suffix = model[model.index(after: lastDash)...]
        if suffix.count == 8, suffix.allSatisfy({ $0.isNumber }) {
            return String(model[..<lastDash])
        }
        return model
    }

    private func monthName(_ month: Int) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard month >= 1 && month <= 12 else { return "" }
        return months[month - 1]
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        refreshData()
        let interval = AppSettings.shared.refreshInterval
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.loadData()
            }
        }
    }

    func restartAutoRefresh() {
        inputHistory = []
        outputHistory = []
        startAutoRefresh()
    }

    static func formatCost(_ cost: Double) -> String {
        let sign = cost < 0 ? "-" : ""
        let amount = abs(cost)
        if amount >= 1_000_000 {
            return String(format: "%@$%.2fM", sign, amount / 1_000_000)
        }
        if amount >= 10_000 {
            return String(format: "%@$%.1fK", sign, amount / 1_000)
        }
        if amount >= 1_000 {
            return String(format: "%@$%.2fK", sign, amount / 1_000)
        }
        return String(format: "%@$%.2f", sign, amount)
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.2f B", Double(count) / 1_000_000_000)
        } else if count >= 100_000_000 {
            return String(format: "%.1f M", Double(count) / 1_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.2f M", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1f K", Double(count) / 1_000)
        }
        return String(count)
    }

    // iStats 风格：量级并入单位（t/s、Kt/s、Mt/s），数值不超过 3 位有效数字
    static func formatRate(_ tokensPerSec: Double) -> (value: String, unit: String) {
        func scaled(_ v: Double) -> String {
            String(format:  "%.0f", v)
        }
        
        switch tokensPerSec {
        case ..<0.1:
            return ("0", "T/s")
        case ..<1_000:
            return (String(format: "%.0f", tokensPerSec), "T/s")
        case ..<1_000_000:
            // 把 K 拼在 value 里，unit 保持 T/s
            return (scaled(tokensPerSec / 1_000) + "K", "T/s")
        case ..<1_000_000_000:
            // 把 M 拼在 value 里
            return (scaled(tokensPerSec / 1_000_000) + "M", "T/s")
        default:
            // 把 G 拼在 value 里
            return (scaled(tokensPerSec / 1_000_000_000) + "G", "T/s")
        }
    }

    // MARK: - 本地限额估算（官方 API 与守护进程都不可用时的兜底方案）

    /// 基于本地 JSONL 数据计算限额估算
    /// 限额取历史用量 P90（同 Claude-Code-Usage-Monitor 的 custom plan 算法），
    /// 返回 V4StateProtocol 结构，与官方数据格式一致，方便 UI 统一处理
    private func calculateLocalRateLimits(from entries: [UsageEntry], now: Date) -> V4StateProtocol? {
        guard !entries.isEmpty else { return nil }

        let fiveHourAgo = now.addingTimeInterval(-5 * 3600)
        let sevenDayAgo = now.addingTimeInterval(-7 * 24 * 3600)

        // 计算最近 5 小时用量
        let fiveHourTokens = entries
            .filter { $0.timestamp >= fiveHourAgo }
            .reduce(0) { $0 + totalTokens(in: $1) }

        // 计算最近 7 天用量
        let sevenDayTokens = entries
            .filter { $0.timestamp >= sevenDayAgo }
            .reduce(0) { $0 + totalTokens(in: $1) }

        // 限额估算：历史会话块/周用量的 P90，且不低于当前已用量（保证百分比 ≤100）
        let fiveHourLimit = max(estimatedFiveHourLimit(from: entries), fiveHourTokens, 1)
        let sevenDayLimit = max(estimatedSevenDayLimit(from: entries), sevenDayTokens, 1)

        let calendar = Calendar.current

        // 5 小时窗口重置时间：按滑动窗口，即当前时间 + (5小时 - 已过去的时间)
        let fiveHourReset: Date
        if let oldestEntry = entries.filter({ $0.timestamp >= fiveHourAgo }).min(by: { $0.timestamp < $1.timestamp }) {
            fiveHourReset = oldestEntry.timestamp.addingTimeInterval(5 * 3600)
        } else {
            fiveHourReset = now.addingTimeInterval(5 * 3600)
        }

        // 7 天窗口重置时间：按下周一 00:00 本地时间
        let weekday = calendar.component(.weekday, from: now)
        let daysToMonday = (weekday + 5) % 7
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day! += (7 - daysToMonday)
        let sevenDayReset = calendar.date(from: components) ?? now.addingTimeInterval(7 * 24 * 3600)

        // 计算相对时间字符串
        let fiveHourResetStr = formatRelativeTime(from: now, to: fiveHourReset)
        let sevenDayResetStr = formatRelativeTime(from: now, to: sevenDayReset)

        let fiveHourDetail = V4LimitDetail(
            used_percentage: min(100.0, Double(fiveHourTokens) / Double(fiveHourLimit) * 100),
            tokens_used: fiveHourTokens,
            token_limit: fiveHourLimit,
            resets_at: fiveHourResetStr
        )

        let sevenDayDetail = V4LimitDetail(
            used_percentage: min(100.0, Double(sevenDayTokens) / Double(sevenDayLimit) * 100),
            tokens_used: sevenDayTokens,
            token_limit: sevenDayLimit,
            resets_at: sevenDayResetStr
        )

        return V4StateProtocol(
            schema_version: "1.0-local",
            generated_at: ISO8601DateFormatter().string(from: now),
            confidence: "local_estimate",
            stale: false,
            plan: "custom",
            limits: V4Limits(five_hour: fiveHourDetail, seven_day: sevenDayDetail),
            local: nil,
            local_history: nil
        )
    }

    /// 5 小时限额估算：把历史条目按 5 小时会话块聚合（窗口自首条消息起算 5 小时），
    /// 取各块 token 总量的 P90
    private func estimatedFiveHourLimit(from entries: [UsageEntry]) -> Int {
        var blockSums: [Int] = []
        var blockStart: Date?
        var blockSum = 0

        // entries 已按 timestamp 升序（loadAllData 排序过）
        for entry in entries {
            if let start = blockStart, entry.timestamp.timeIntervalSince(start) < 5 * 3600 {
                blockSum += totalTokens(in: entry)
            } else {
                if blockStart != nil { blockSums.append(blockSum) }
                blockStart = entry.timestamp
                blockSum = totalTokens(in: entry)
            }
        }
        if blockStart != nil { blockSums.append(blockSum) }

        return percentile90(of: blockSums)
    }

    /// 7 天限额估算：按自然周聚合的 token 总量 P90
    private func estimatedSevenDayLimit(from entries: [UsageEntry]) -> Int {
        let calendar = Calendar.current
        var weekSums: [Date: Int] = [:]
        for entry in entries {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.timestamp)
            guard let weekStart = calendar.date(from: comps) else { continue }
            weekSums[weekStart, default: 0] += totalTokens(in: entry)
        }
        return percentile90(of: Array(weekSums.values))
    }

    private func percentile90(of values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int((Double(sorted.count) * 0.9).rounded(.up)) - 1)
        return sorted[max(0, index)]
    }

    /// 格式化为相对时间字符串（如 "in 2h 15m"）
    private func formatRelativeTime(from: Date, to: Date) -> String {
        let interval = to.timeIntervalSince(from)
        guard interval > 0 else { return "now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "in \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "in \(hours)h"
        } else {
            return "in \(minutes)m"
        }
    }
}
