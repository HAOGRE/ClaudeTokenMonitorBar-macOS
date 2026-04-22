import Foundation
import Observation
import os.log

// MARK: - 监控数据 Model

struct MonitoringData {
    var totalCost: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    // 今日统计
    var todayCost: Double = 0
    var todayInputTokens: Int = 0
    var todayOutputTokens: Int = 0
    var todayCacheReadTokens: Int = 0
    var projectCosts: [String: Double] = [:]
    var modelDistribution: [String: Int] = [:]
    var recentEntries: [UsageEntry] = []
    var lastUpdated: Date = Date()

    static var empty: MonitoringData { MonitoringData() }
}

// MARK: - Token 速率（每秒增量）

struct TokenRate {
    /// 输入 token/s（对应"上行"：你发给 Claude 的）
    var inputPerSec: Double = 0
    /// 输出 token/s（对应"下行"：Claude 回复你的）
    var outputPerSec: Double = 0

    var hasActivity: Bool { inputPerSec > 0 || outputPerSec > 0 }
}

// MARK: - 后台加载结果

private struct LoadResult: Sendable {
    let stats: UsageStatistics
    let todayStats: UsageStatistics
    let projects: [String: UsageStatistics]
    let dailyData: [Date: UsageStatistics]
}

// MARK: - 监控视图模型

@Observable
@MainActor
final class MonitoringViewModel {
    var monitoringData: MonitoringData = .empty
    var tokenRate: TokenRate = TokenRate()
    var isLoading = false
    var errorMessage: String?
    /// 30天每日历史，用于柱状图
    var dailyHistory: [(day: Date, cost: Double, tokens: Int)] = []

    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "viewmodel")
    private let tokenReader = TokenDataReader()
    nonisolated(unsafe) private var autoRefreshTask: Task<Void, Never>?

    /// 重置日期（持久化到 UserDefaults）
    private var resetDate: Date? {
        get { UserDefaults.standard.object(forKey: "statsResetDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "statsResetDate") }
    }

    // 上一次采样的数据（用于计算速率）
    private var lastSampleInput: Int = 0
    private var lastSampleOutput: Int = 0
    private var lastSampleTime: Date = Date()
    private var isFirstLoad = true

    // 速率平滑：保留最近 N 个采样做滑动平均
    private var inputHistory: [Double] = []
    private var outputHistory: [Double] = []
    private let historySize = 5

    init() {
        startAutoRefresh()
    }

    // MARK: - 数据加载

    func refreshData() {
        Task {
            await loadData()
        }
    }

    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let reader = tokenReader
        let capturedResetDate = resetDate
        let result = await Task.detached(priority: .userInitiated) {
            let allData = reader.loadAllData(since: capturedResetDate, daysBack: 30)
            let stats      = UsageStatistics(entries: allData.allEntries)
            let todayStats = UsageStatistics(entries: allData.todayEntries)
            let projects   = allData.projectEntries.mapValues { UsageStatistics(entries: $0) }
            let dailyData  = allData.dailyEntries.mapValues  { UsageStatistics(entries: $0) }
            return LoadResult(stats: stats, todayStats: todayStats, projects: projects, dailyData: dailyData)
        }.value

        updateMonitoringData(from: result.stats, todayStats: result.todayStats, projectData: result.projects, dailyData: result.dailyData)

        if result.stats.entries.isEmpty {
            errorMessage = "未找到数据，请检查 ~/.claude/projects 目录"
        }

        isLoading = false
    }

    private func updateMonitoringData(from stats: UsageStatistics, todayStats: UsageStatistics, projectData: [String: UsageStatistics], dailyData: [Date: UsageStatistics]) {
        let now = Date()
        let newInput = stats.totalInputTokens
        let newOutput = stats.totalOutputTokens

        // 计算速率（跳过首次加载避免虚假峰值）
        if !isFirstLoad {
            let elapsed = now.timeIntervalSince(lastSampleTime)
            if elapsed > 0 {
                let rawInputRate = Double(max(0, newInput - lastSampleInput)) / elapsed
                let rawOutputRate = Double(max(0, newOutput - lastSampleOutput)) / elapsed

                // 滑动平均平滑
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

        lastSampleInput = newInput
        lastSampleOutput = newOutput
        lastSampleTime = now

        var updated = MonitoringData()
        updated.totalCost = stats.totalCost
        updated.totalInputTokens = newInput
        updated.totalOutputTokens = newOutput
        updated.totalCacheReadTokens = stats.totalCacheReadTokens
        updated.todayCost = todayStats.totalCost
        updated.todayInputTokens = todayStats.totalInputTokens
        updated.todayOutputTokens = todayStats.totalOutputTokens
        updated.todayCacheReadTokens = todayStats.totalCacheReadTokens
        updated.modelDistribution = stats.modelDistribution
        updated.recentEntries = Array(stats.entries.suffix(5))
        updated.lastUpdated = now
        updated.projectCosts = projectData.mapValues { $0.totalCost }

        dailyHistory = dailyData
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, cost: $0.value.totalCost, tokens: $0.value.totalInputTokens + $0.value.totalOutputTokens) }

        monitoringData = updated
        logger.info("速率: ↑\(String(format: "%.1f", self.tokenRate.inputPerSec))/s ↓\(String(format: "%.1f", self.tokenRate.outputPerSec))/s")
    }

    // MARK: - 自动刷新

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

    // MARK: - 数据查询

    func getTopProjects(limit: Int = 5) -> [(String, Double)] {
        monitoringData.projectCosts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    func getModelStatistics() -> [(String, Int)] {
        monitoringData.modelDistribution
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    /// 重置统计起始时间（不删除 JSONL 文件，只过滤显示范围）
    func resetStats() {
        UserDefaults.standard.set(Date(), forKey: "statsResetDate")
        dailyHistory = []
        monitoringData = .empty
        inputHistory = []
        outputHistory = []
        lastSampleInput = 0
        lastSampleOutput = 0
        lastSampleTime = Date()
        isFirstLoad = true
        refreshData()
    }

    // MARK: - 格式化工具

    static func formatCost(_ cost: Double) -> String {
        String(format: "$%.2f", cost)
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 100_000_000 {
            // M 值 ≥ 100：显示 M（如 273.5 M）
            return String(format: "%.1f M", Double(count) / 1_000_000)
        } else if count >= 1_000_000 {
            // M 值 < 100：降级显示精确 K 整数（如 2098 K）
            return "\(count / 1_000) K"
        } else if count >= 1_000 {
            return String(format: "%.1f K", Double(count) / 1_000)
        }
        return String(count)
    }

    /// 格式化速率，单位：t/s、Kt/s、Mt/s、Gt/s（以 1000 为基数）
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

