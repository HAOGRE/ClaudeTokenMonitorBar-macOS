import Foundation
import Observation
import os.log
import SwiftUI

// MARK: - 新的 TokenScope 风格数据结构

struct Metrics {
    var totalTokens: Int = 0
    var inputTokens: Int = 0
    var cacheTokens: Int = 0
    var outputTokens: Int = 0
    var cost: Double = 0
    var requests: Int = 0
    var sessions: Int = 0
    var deltaTokens: Double = 0 // pct
}

struct ModelStat: Identifiable {
    var id: String { name }
    var name: String
    var vendor: String = "Anthropic"
    var tokens: Int = 0
    var cost: Double = 0
    var color: Color = .green
    var priced: Bool = true
}

struct NamedCount: Identifiable {
    var id: String { name }
    var name: String
    var count: Int
}

struct SeriesPoint: Identifiable {
    var id: String { label }
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

struct MonitoringData {
    var dashboard: Dashboard = .empty
    var lastUpdated: Date = Date()
    var v4State: V4StateProtocol? = nil
    var recentEntries: [UsageEntry] = []
    
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
}

// MARK: - 监控视图模型

@Observable
@MainActor
final class MonitoringViewModel {
    var monitoringData: MonitoringData = .empty
    var tokenRate: TokenRate = TokenRate()
    var isLoading = false
    var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "viewmodel")
    private let tokenReader = TokenDataReader()
    private let stateReader = StateProtocolReader()
    nonisolated(unsafe) private var autoRefreshTask: Task<Void, Never>?

    private var resetDate: Date? {
        get { UserDefaults.standard.object(forKey: "statsResetDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "statsResetDate") }
    }

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

    func refreshData() {
        Task { await loadData() }
    }

    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let reader = tokenReader
        let stateR = stateReader
        let capturedResetDate = resetDate
        
        let (result, state) = await Task.detached(priority: .userInitiated) {
            let v4State = await stateR.readState()
            // 加载约半年数据以便生成 Tokenscope 风格热力图
            let allData = reader.loadAllData(since: capturedResetDate, daysBack: 190)
            return (LoadResult(allEntries: allData.allEntries, todayEntries: allData.todayEntries, projectEntries: allData.projectEntries, dailyEntries: allData.dailyEntries), v4State)
        }.value

        updateMonitoringData(from: result, v4State: state)

        if result.allEntries.isEmpty && state == nil {
            errorMessage = "未找到数据，请检查本地用量数据目录访问权限"
        }

        isLoading = false
    }

    private func updateMonitoringData(from result: LoadResult, v4State: V4StateProtocol?) {
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

        // 构建 Dashboard
        var dashboard = Dashboard()
        dashboard.day = buildPeriodReport(entries: result.allEntries.filter { now.timeIntervalSince($0.timestamp) <= 86400 }, period: .day)
        dashboard.week = buildPeriodReport(entries: result.allEntries.filter { now.timeIntervalSince($0.timestamp) <= 86400 * 7 }, period: .week)
        dashboard.month = buildPeriodReport(entries: result.allEntries.filter { now.timeIntervalSince($0.timestamp) <= 86400 * 30 }, period: .month)
        
        // 项目聚合放入全局或随期间，为了性能，我们将全局项目放入 month，或者按实际 entries 聚合
        // 此处直接聚合 allEntries 为项目
        var projects: [String: Int] = [:]
        for (proj, entries) in result.projectEntries {
            projects[proj] = entries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
        }
        let projectList = projects.map { NamedCount(name: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
        
        dashboard.day.projects = projectList
        dashboard.week.projects = projectList
        dashboard.month.projects = projectList

        // 构建 Heatmap
        var heatmapMap: [Date: Int] = [:]
        for entry in result.allEntries {
            let start = calendar.startOfDay(for: entry.timestamp)
            heatmapMap[start, default: 0] += (entry.inputTokens + entry.outputTokens)
        }
        
        let startOfToday = calendar.startOfDay(for: now)
        let heatmapDaysCount = 26 * 7 // 过去 26 周
        var heatmap: [HeatDay] = []
        
        // 找出最大的 tokens 用于计算 level (0-4)
        let maxTokens = heatmapMap.values.max() ?? 1
        
        for i in (0..<heatmapDaysCount).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                let tokens = heatmapMap[date] ?? 0
                var level = 0
                if tokens > 0 {
                    let ratio = Double(tokens) / Double(maxTokens)
                    if ratio > 0.75 { level = 4 }
                    else if ratio > 0.5 { level = 3 }
                    else if ratio > 0.25 { level = 2 }
                    else { level = 1 }
                }
                heatmap.append(HeatDay(date: date, tokens: tokens, level: level))
            }
        }
        dashboard.heatmap = heatmap
        
        var updated = MonitoringData()
        updated.dashboard = dashboard
        updated.lastUpdated = now
        updated.v4State = v4State
        updated.recentEntries = Array(result.allEntries.suffix(5))
        
        monitoringData = updated
    }
    
    private enum Period { case day, week, month }
    
    private func buildPeriodReport(entries: [UsageEntry], period: Period) -> PeriodReport {
        var report = PeriodReport()
        var metrics = Metrics()
        metrics.totalTokens = entries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens + $1.cacheReadTokens + $1.cacheCreationTokens }
        metrics.inputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        metrics.cacheTokens = entries.reduce(0) { $0 + $1.cacheReadTokens + $1.cacheCreationTokens }
        metrics.outputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        metrics.cost = entries.reduce(0) { $0 + $1.costUsd }
        metrics.requests = entries.count
        
        // 计算 sessions (简单按 messageId 聚合)
        let sessions = Set(entries.map { $0.messageId }).count
        metrics.sessions = sessions
        report.metrics = metrics
        
        // 聚合模型
        let donutPalette: [Color] = [.green, .mint, .teal, .cyan, .blue, .indigo, .purple]
        var modelDict: [String: (tokens: Int, cost: Double)] = [:]
        for entry in entries {
            let m = entry.model.isEmpty ? "unknown" : entry.model
            let cur = modelDict[m] ?? (0, 0.0)
            modelDict[m] = (cur.tokens + entry.inputTokens + entry.outputTokens + entry.cacheReadTokens, cur.cost + entry.costUsd)
        }
        var models = modelDict.map { k, v in ModelStat(name: k, tokens: v.tokens, cost: v.cost, color: .gray) }
        models.sort { $0.cost > $1.cost }
        for i in 0..<models.count {
            models[i].color = i < donutPalette.count ? donutPalette[i] : .gray
        }
        report.models = models
        
        // Series & Trend
        let calendar = Calendar.current
        var seriesDict: [String: (label: String, full: String, input: Int, cache: Int, output: Int, date: Date)] = [:]
        
        for entry in entries {
            let label: String
            let full: String
            let groupDate: Date
            
            switch period {
            case .day:
                // 按小时
                let comps = calendar.dateComponents([.year, .month, .day, .hour], from: entry.timestamp)
                groupDate = calendar.date(from: comps)!
                label = "\(comps.hour!)h"
                full = "\(comps.month!)/\(comps.day!) \(comps.hour!):00"
            case .week:
                let start = calendar.startOfDay(for: entry.timestamp)
                groupDate = start
                let comps = calendar.dateComponents([.month, .day], from: start)
                let weekdayIndex = calendar.component(.weekday, from: start) - 1
                label = calendar.shortWeekdaySymbols[weekdayIndex]
                full = "\(comps.month!)/\(comps.day!)"
            case .month:
                // 按天
                let start = calendar.startOfDay(for: entry.timestamp)
                groupDate = start
                let comps = calendar.dateComponents([.month, .day], from: start)
                label = "\(comps.month!)/\(comps.day!)"
                full = label
            }
            
            let key = full
            let cur = seriesDict[key] ?? (label, full, 0, 0, 0, groupDate)
            seriesDict[key] = (
                label,
                full,
                cur.input + entry.inputTokens,
                cur.cache + entry.cacheReadTokens + entry.cacheCreationTokens,
                cur.output + entry.outputTokens,
                groupDate
            )
        }
        
        report.series = seriesDict.values.sorted { $0.date < $1.date }.map {
            SeriesPoint(label: $0.label, full: $0.full, input: $0.input, cache: $0.cache, output: $0.output)
        }
        
        // 简单趋势线 (Sparkline) - 使用 cost 和 request 的滑动聚合
        report.costTrend = report.series.map { Double($0.input + $0.cache + $0.output) } // mock cost trend by tokens for now
        report.reqTrend = report.series.map { Double($0.input) } // mock req trend
        
        return report
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

    func resetStats() {
        UserDefaults.standard.set(Date(), forKey: "statsResetDate")
        monitoringData = .empty
        inputHistory = []
        outputHistory = []
        lastSampleInput = 0
        lastSampleOutput = 0
        lastSampleTime = Date()
        isFirstLoad = true
        refreshData()
    }

    static func formatCost(_ cost: Double) -> String {
        String(format: "$%.2f", cost)
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f M", Double(count) / 1_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.2f M", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1f K", Double(count) / 1_000)
        }
        return String(count)
    }

    static func formatRate(_ tokensPerSec: Double) -> String {
        switch tokensPerSec {
        case ..<0.1:
            return "0 T/s"
        case ..<1_000:
            return String(format: "%.0f t/s", tokensPerSec)
        case ..<1_000_000:
            return String(format: "%.1fK t/s", tokensPerSec / 1_000)
        case ..<1_000_000_000:
            return String(format: "%.1fM t/s", tokensPerSec / 1_000_000)
        default:
            return String(format: "%.1fG t/s", tokensPerSec / 1_000_000_000)
        }
    }
}
