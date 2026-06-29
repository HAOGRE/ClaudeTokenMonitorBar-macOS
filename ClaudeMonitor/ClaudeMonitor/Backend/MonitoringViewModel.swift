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

    // V4 状态协议数据
    var v4State: V4StateProtocol? = nil

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

private struct BackgroundLoadResult: Sendable {
    let claudeResult: LoadResult
    let v4State: V4StateProtocol?
    let codexData: AllAgentData?
}

// MARK: - 监控视图模型

@Observable
@MainActor
final class MonitoringViewModel {
    // ── 现有 Claude Code 数据（向后兼容）──────────────────────────
    var monitoringData: MonitoringData = .empty
    var tokenRate: TokenRate = TokenRate()
    var isLoading = false
    var errorMessage: String?
    /// 30天每日历史，用于柱状图
    var dailyHistory: [(day: Date, cost: Double, tokens: Int)] = []

    // ── 多 Agent 数据 ─────────────────────────────────────────────
    /// 所有已安装 Agent 的聚合数据（包含 Claude、Codex、Gemini 等）
    var agentsData: [AllAgentData] = []

    // ── 聚合计算属性（跨所有 Agent 叠加）─────────────────────────

    /// 聚合实时速率：所有 Agent 的输入/输出速率叠加
    var aggregatedTokenRate: TokenRate {
        var inputSum: Double = 0
        var outputSum: Double = 0
        for rate in agentRates.values {
            inputSum  += rate.inputPerSec
            outputSum += rate.outputPerSec
        }
        return TokenRate(inputPerSec: inputSum, outputPerSec: outputSum)
    }

    /// 所有 Agent 今日总成本
    var aggregatedTodayCost: Double {
        agentsData.reduce(0) { $0 + $1.todayCost }
    }

    /// 所有 Agent 累计总成本
    var aggregatedTotalCost: Double {
        agentsData.reduce(0) { $0 + $1.totalCost }
    }

    /// 所有 Agent 今日输入 token 总数
    var aggregatedTodayInputTokens: Int {
        agentsData.reduce(0) { $0 + $1.todayInputTokens }
    }

    /// 所有 Agent 今日输出 token 总数
    var aggregatedTodayOutputTokens: Int {
        agentsData.reduce(0) { $0 + $1.todayOutputTokens }
    }

    // ── 私有状态 ──────────────────────────────────────────────────
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "viewmodel")
    private let tokenReader = TokenDataReader()
    private let stateReader = StateProtocolReader()
    nonisolated(unsafe) private var autoRefreshTask: Task<Void, Never>?

    /// 每个 Agent 的实时速率（key = agentId）
    private var agentRates: [AgentKind: TokenRate] = [:]

    /// 每个 Agent 的上次采样数据
    private struct AgentSample {
        var input: Int = 0
        var output: Int = 0
        var time: Date = Date()
        var isFirstLoad: Bool = true
        var inputHistory: [Double] = []
        var outputHistory: [Double] = []
    }
    private var agentSamples: [AgentKind: AgentSample] = [:]
    private let historySize = 5

    /// 重置日期（持久化到 UserDefaults）
    private var resetDate: Date? {
        get { UserDefaults.standard.object(forKey: "statsResetDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "statsResetDate") }
    }

    // 保留旧速率字段（供向后兼容 — ClaudeMonitorApp.swift 的 MenuBarLabel 通过 aggregatedTokenRate 读取）
    private var lastSampleInput: Int = 0
    private var lastSampleOutput: Int = 0
    private var lastSampleTime: Date = Date()
    private var isFirstLoad = true
    private var inputHistory: [Double] = []
    private var outputHistory: [Double] = []

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
        let stateR = stateReader
        let capturedResetDate = resetDate

        // 并发读取：Claude（现有逻辑）+ 其他 Agent
        let bgResult: BackgroundLoadResult = await Task.detached(priority: .userInitiated) {
            // Claude Code 数据（原有路径）
            let v4State = await stateR.readState()
            let allData = reader.loadRawAllData(since: capturedResetDate, daysBack: 30)
            let stats      = UsageStatistics(entries: allData.allEntries)
            let todayStats = UsageStatistics(entries: allData.todayEntries)
            let projects   = allData.projectEntries.mapValues { UsageStatistics(entries: $0) }
            let dailyData  = allData.dailyEntries.mapValues  { UsageStatistics(entries: $0) }
            let claudeResult = LoadResult(stats: stats, todayStats: todayStats, projects: projects, dailyData: dailyData)

            // Codex 数据（新增）
            let codexReader = CodexLogReader()
            let codexAgentData: AllAgentData? = codexReader.isInstalled
                ? codexReader.loadAllData(since: capturedResetDate, daysBack: 30)
                : nil

            return BackgroundLoadResult(claudeResult: claudeResult, v4State: v4State, codexData: codexAgentData)
        }.value

        let result   = bgResult.claudeResult
        let state    = bgResult.v4State
        let codexData = bgResult.codexData

        // 更新现有 monitoringData（Claude 专用，向后兼容）
        updateMonitoringData(
            from: result.stats,
            todayStats: result.todayStats,
            projectData: result.projects,
            dailyData: result.dailyData,
            v4State: state
        )

        // 构建 Claude 的 AllAgentData（含 v4 限额状态）
        let claudeAgentData = buildClaudeAgentData(
            from: result.stats,
            todayStats: result.todayStats,
            projectData: result.projects,
            dailyData: result.dailyData,
            v4State: state
        )

        // 更新聚合 agents 列表
        var newAgents: [AllAgentData] = [claudeAgentData]
        if let codex = codexData {
            newAgents.append(codex)
        }
        agentsData = newAgents

        // 更新每个 Agent 的实时速率
        updateAgentRate(for: .claude, input: result.stats.totalInputTokens, output: result.stats.totalOutputTokens)
        if let codex = codexData {
            updateAgentRate(for: .codex, input: codex.totalInputTokens, output: codex.totalOutputTokens)
        }

        if result.stats.entries.isEmpty && state == nil {
            errorMessage = "未找到数据，请检查本地用量数据目录访问权限"
        }

        isLoading = false
    }

    // MARK: - 构建 Claude AllAgentData

    private func buildClaudeAgentData(
        from stats: UsageStatistics,
        todayStats: UsageStatistics,
        projectData: [String: UsageStatistics],
        dailyData: [Date: UsageStatistics],
        v4State: V4StateProtocol?
    ) -> AllAgentData {
        let projectCosts = projectData.mapValues { $0.totalCost }
        let daily = dailyData
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, cost: $0.value.totalCost,
                    tokens: $0.value.entries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }) }
        let rateLimitState: AgentRateLimitState? = v4State.flatMap { AgentRateLimitState.from(v4State: $0) }

        // 若 v4 state 提供了更权威的总成本，优先使用
        var totalCost = stats.totalCost
        if let s = v4State, let history = s.local_history, let tCost = history.total_cost_usd, tCost > 0 {
            totalCost = tCost
        }

        return AllAgentData(
            agentKind: .claude,
            totalCost: totalCost,
            totalInputTokens: stats.totalInputTokens,
            totalOutputTokens: stats.totalOutputTokens,
            totalCacheReadTokens: stats.totalCacheReadTokens,
            todayCost: todayStats.totalCost,
            todayInputTokens: todayStats.totalInputTokens,
            todayOutputTokens: todayStats.totalOutputTokens,
            todayCacheReadTokens: todayStats.totalCacheReadTokens,
            recentEntries: Array(stats.entries.suffix(5)),
            projectCosts: projectCosts,
            dailyHistory: daily,
            rateLimitState: rateLimitState
        )
    }

    // MARK: - 每个 Agent 的速率更新

    private func updateAgentRate(for kind: AgentKind, input: Int, output: Int) {
        let now = Date()
        var sample = agentSamples[kind] ?? AgentSample()

        if !sample.isFirstLoad {
            let elapsed = now.timeIntervalSince(sample.time)
            if elapsed > 0 {
                let rawInputRate  = Double(max(0, input  - sample.input))  / elapsed
                let rawOutputRate = Double(max(0, output - sample.output)) / elapsed

                sample.inputHistory.append(rawInputRate)
                sample.outputHistory.append(rawOutputRate)
                if sample.inputHistory.count  > historySize { sample.inputHistory.removeFirst() }
                if sample.outputHistory.count > historySize { sample.outputHistory.removeFirst() }

                let iCount = Double(sample.inputHistory.count)
                let oCount = Double(sample.outputHistory.count)
                agentRates[kind] = TokenRate(
                    inputPerSec:  iCount > 0 ? sample.inputHistory.reduce(0, +)  / iCount : 0,
                    outputPerSec: oCount > 0 ? sample.outputHistory.reduce(0, +) / oCount : 0
                )
            }
        } else {
            sample.isFirstLoad = false
        }

        sample.input  = input
        sample.output = output
        sample.time   = now
        agentSamples[kind] = sample
    }

    // MARK: - 现有 monitoringData 更新（保持 Claude 专用路径，向后兼容）

    private func updateMonitoringData(from stats: UsageStatistics, todayStats: UsageStatistics, projectData: [String: UsageStatistics], dailyData: [Date: UsageStatistics], v4State: V4StateProtocol?) {
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
        updated.v4State = v4State

        // 如果 v4 状态提供了更权威的全部消耗，可覆盖（根据需求，这里我们主要保留官方数据作参考或限额显示，所以优先使用底层计算的今日消费等）
        if let state = v4State, let history = state.local_history, let tCost = history.total_cost_usd, tCost > 0 {
            updated.totalCost = tCost
        }

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
        agentRates = [:]
        agentSamples = [:]
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
        agentsData = []
        agentRates = [:]
        agentSamples = [:]
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
