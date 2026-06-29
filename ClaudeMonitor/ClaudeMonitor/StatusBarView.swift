//
//  StatusBarView.swift
//  ClaudeMonitor
//
//  菜单栏点击后弹出的详情面板
//

import SwiftUI
import Charts

struct StatusBarView: View {
    @Environment(MonitoringViewModel.self) private var viewModel
    @State private var showingTodayStats = false
    @State private var showingChart = false
    @State private var showingSettings = false
    /// 当前展开的 Agent（nil = 全部折叠，展开时显示该 Agent 的详情区块）
    @State private var expandedAgent: AgentKind? = nil
    private var settings: AppSettings { AppSettings.shared }
    private var l10n: L10n { L10n.shared }

    var body: some View {
        if showingSettings {
            SettingsView { showingSettings = false }
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // ── 顶部标题栏 ──────────────────────────────────────
            headerBar

            Divider()

            // ── 核心统计卡片 ────────────────────────────────────
            statsGrid
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // ── Agents 概览（多 Agent 时显示）─────────────────────
            Divider()
                .padding(.vertical, 8)
            agentsSection
                .padding(.horizontal, 16)

            // ── 展开 Agent 的详情区块 ───────────────────────────
            if let expanded = expandedAgent,
               let agentData = viewModel.agentsData.first(where: { $0.agentKind == expanded }) {

                // Claude 专有：v4 官方限制状态
                if expanded == .claude,
                   let v4State = viewModel.monitoringData.v4State,
                   let fiveHour = v4State.limits?.five_hour {
                    Divider()
                        .padding(.vertical, 8)
                    v4LimitSection(fiveHour: fiveHour)
                        .padding(.horizontal, 16)
                }

                // 各 Agent 通用限额状态
                if expanded != .claude,
                   let rateLimit = agentData.rateLimitState {
                    Divider()
                        .padding(.vertical, 8)
                    agentRateLimitSection(rateLimit: rateLimit, agentName: expanded.displayName)
                        .padding(.horizontal, 16)
                }

                // 项目成本排行（展开 Agent 专属数据）
                if settings.showProjectSection && !agentData.projectCosts.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    agentProjectSection(projectCosts: agentData.projectCosts)
                        .padding(.horizontal, 16)
                }

                // 最近记录（展开 Agent 专属数据）
                if settings.showRecentSection && !agentData.recentEntries.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    agentRecentSection(entries: agentData.recentEntries)
                        .padding(.horizontal, 16)
                }
            }

            // ── 30天趋势图（可折叠）────────────────────────────
            if settings.showChartSection {
                Divider()
                    .padding(.vertical, 8)
                chartSection
                    .padding(.horizontal, 16)
            }

            Divider()

            // ── 底部工具栏 ──────────────────────────────────────
            bottomBar
        }
        .frame(width: 340)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - 顶部标题栏

    private var headerBar: some View {
        HStack {
            Image(systemName: "cpu.fill")
                .foregroundColor(.accentColor)
            Text(l10n.appTitle)
                .font(.headline)

            Spacer()

            // 更新时间（始终占位，loading 时叠加旋转图标避免布局抖动）
            Text(viewModel.monitoringData.lastUpdated, format: .dateTime.hour().minute().second())
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(viewModel.isLoading ? 0 : 1)
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

            Button {
                viewModel.refreshData()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 核心统计卡片 + 实时速率

    private var statsGrid: some View {
        // 顶部统计区显示聚合数据（所有 Agent 叠加）
        // 使用聚合速率保持与状态栏图标一致
        let rate = viewModel.aggregatedTokenRate

        // 多 Agent 有数据时用聚合值，否则回退到 Claude 专用数据保持兼容
        let hasMultiAgent = viewModel.agentsData.count > 1
        let data = viewModel.monitoringData
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let cacheTokens: Int
        if hasMultiAgent {
            cost         = showingTodayStats ? viewModel.aggregatedTodayCost          : viewModel.aggregatedTotalCost
            inputTokens  = showingTodayStats ? viewModel.aggregatedTodayInputTokens   : viewModel.agentsData.reduce(0) { $0 + $1.totalInputTokens }
            outputTokens = showingTodayStats ? viewModel.aggregatedTodayOutputTokens  : viewModel.agentsData.reduce(0) { $0 + $1.totalOutputTokens }
            cacheTokens  = showingTodayStats ? viewModel.agentsData.reduce(0) { $0 + $1.todayCacheReadTokens }
                                             : viewModel.agentsData.reduce(0) { $0 + $1.totalCacheReadTokens }
        } else {
            cost         = showingTodayStats ? data.todayCost         : data.totalCost
            inputTokens  = showingTodayStats ? data.todayInputTokens  : data.totalInputTokens
            outputTokens = showingTodayStats ? data.todayOutputTokens : data.totalOutputTokens
            cacheTokens  = showingTodayStats ? data.todayCacheReadTokens : data.totalCacheReadTokens
        }
        let _ = data  // suppress unused warning when hasMultiAgent
        return VStack(spacing: 8) {
            // ── 全部 / 今天 切换 ─────────────────────────────────
            Picker("", selection: $showingTodayStats) {
                Text(l10n.str(.pickerAll)).tag(false)
                Text(l10n.str(.pickerToday)).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // ── 实时速率行（仿 iStat）────────────────────────────
            RateBar(rate: rate)

            // ── 统计卡片（2x2）──────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCell(
                    icon: "dollarsign.circle.fill",
                    iconColor: .green,
                    label: showingTodayStats ? l10n.str(.todayCost) : l10n.str(.totalCost),
                    value: MonitoringViewModel.formatCost(cost)
                )
                StatCell(
                    icon: "arrow.down.circle.fill",
                    iconColor: .blue,
                    label: l10n.str(.inputTokens),
                    value: MonitoringViewModel.formatTokens(inputTokens)
                )
                StatCell(
                    icon: "arrow.up.circle.fill",
                    iconColor: .orange,
                    label: l10n.str(.outputTokens),
                    value: MonitoringViewModel.formatTokens(outputTokens)
                )
                StatCell(
                    icon: "memorychip.fill",
                    iconColor: .purple,
                    label: l10n.str(.cacheRead),
                    value: MonitoringViewModel.formatTokens(cacheTokens)
                )
            }
        }
    }

    // MARK: - Agents 概览 Section

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "AGENTS", systemImage: "bolt.fill")

            if viewModel.agentsData.isEmpty {
                Text("正在加载…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                let totalCost = viewModel.agentsData.reduce(0) { $0 + $1.todayCost }
                ForEach(viewModel.agentsData, id: \.agentKind) { agentData in
                    AgentRow(
                        agentData: agentData,
                        totalCost: max(totalCost, 0.000001),
                        isExpanded: expandedAgent == agentData.agentKind,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedAgent == agentData.agentKind {
                                    expandedAgent = nil
                                } else {
                                    expandedAgent = agentData.agentKind
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Agent 通用限额 Section

    private func agentRateLimitSection(rateLimit: AgentRateLimitState, agentName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "\(agentName) 限额", systemImage: "gauge.medium")

            HStack {
                Text("\(rateLimit.windowMinutes / 60)h 窗口")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", rateLimit.usedPercent))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(rateLimit.usedPercent > 90 ? .red : (rateLimit.usedPercent > 75 ? .orange : .primary))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.separatorColor))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rateLimit.usedPercent > 90 ? Color.red : (rateLimit.usedPercent > 75 ? Color.orange : Color.accentColor))
                        .frame(width: max(0, geo.size.width * CGFloat(rateLimit.usedPercent / 100)), height: 4)
                }
            }
            .frame(height: 4)

            if let resetsAt = rateLimit.resetsDescription {
                Text("重置: \(resetsAt)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Agent 专属项目排行 Section

    private func agentProjectSection(projectCosts: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: l10n.str(.projectSectionTitle), systemImage: "folder.fill")
            let topProjects = projectCosts.sorted { $0.value > $1.value }.prefix(5)
            let maxCost = topProjects.first?.value ?? 1
            ForEach(Array(topProjects), id: \.key) { name, cost in
                ProjectRow(name: name, cost: cost, maxCost: maxCost)
            }
        }
    }

    // MARK: - Agent 专属最近记录 Section

    private func agentRecentSection(entries: [UsageEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: l10n.str(.recentSectionTitle), systemImage: "clock.fill")
            ForEach(Array(entries.suffix(5).reversed())) { entry in
                RecentEntryRow(entry: entry)
            }
        }
    }

    // MARK: - v4 官方限制状态

    private func v4LimitSection(fiveHour: V4LimitDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: l10n.str(.v4SectionTitle), systemImage: "shield.checkerboard")

            let used = fiveHour.tokens_used ?? 0
            let limit = fiveHour.token_limit ?? 1
            let percentage = fiveHour.used_percentage ?? (Double(used) / Double(limit) * 100)

            HStack {
                Text(l10n.str(.v4FiveHourWindow))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(percentage > 90 ? .red : (percentage > 75 ? .orange : .primary))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.separatorColor))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(percentage > 90 ? Color.red : (percentage > 75 ? Color.orange : Color.accentColor))
                        .frame(width: max(0, geo.size.width * CGFloat(percentage / 100)), height: 4)
                }
            }
            .frame(height: 4)

            if let resetsAt = fiveHour.resets_at {
                Text("\(l10n.str(.v4ResetsAt)) \(resetsAt)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - 项目成本排行

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: l10n.str(.projectSectionTitle), systemImage: "folder.fill")

            if viewModel.monitoringData.projectCosts.isEmpty {
                Text(l10n.str(.noProjectData))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                let topProjects = viewModel.getTopProjects(limit: 5)
                let maxCost = topProjects.first?.1 ?? 1
                ForEach(topProjects, id: \.0) { name, cost in
                    ProjectRow(name: name, cost: cost, maxCost: maxCost)
                }
            }
        }
    }

    // MARK: - 最近记录

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: l10n.str(.recentSectionTitle), systemImage: "clock.fill")

            let entries = viewModel.monitoringData.recentEntries.suffix(5).reversed()
            if entries.isEmpty {
                Text(l10n.str(.noRecentData))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(entries)) { entry in
                    RecentEntryRow(entry: entry)
                }
            }
        }
    }

    // MARK: - 30天趋势图（可折叠）

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingChart.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(title: l10n.str(.chartSectionTitle), systemImage: "chart.bar.fill")
                    Spacer()
                    Image(systemName: showingChart ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.borderless)

            if showingChart {
                DailyBarChart(history: viewModel.dailyHistory)
                    .frame(height: 90)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 底部工具栏

    private var bottomBar: some View {
        HStack {
            // 错误提示
            if viewModel.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .imageScale(.small)
                Text(l10n.str(.noDataError))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                // 模型分布摘要
                if let topModel = viewModel.getModelStatistics().first {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                    Text(topModel.0)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 设置按钮
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            // 重置按钮
            Button(l10n.str(.resetButton)) {
                viewModel.resetStats()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            // 退出按钮
            Button(l10n.str(.quitButton)) {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - 子组件：实时速率条（仿 iStat Menus 双行显示）

private struct RateBar: View {
    let rate: TokenRate

    var body: some View {
        HStack(spacing: 0) {
            // 输入速率（上行：你发给 Claude）
            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.blue)
                    .imageScale(.small)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.shared.str(.rateInputLabel))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(MonitoringViewModel.formatRate(rate.inputPerSec))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(rate.inputPerSec > 0 ? .blue : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 28)

            // 输出速率（下行：Claude 回复你）
            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .foregroundColor(.orange)
                    .imageScale(.small)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.shared.str(.rateOutputLabel))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(MonitoringViewModel.formatRate(rate.outputPerSec))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(rate.outputPerSec > 0 ? .orange : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        // 有活动时高亮边框
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    rate.hasActivity ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.3), value: rate.hasActivity)
    }
}

// MARK: - 子组件：统计单元格

private struct StatCell: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .imageScale(.medium)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 子组件：项目行（带进度条）

private struct ProjectRow: View {
    let name: String
    let cost: Double
    let maxCost: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // 项目名（取目录名最后一段，去掉 URL 编码）
                Text(decodedName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(MonitoringViewModel.formatCost(cost))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            // 成本占比进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.separatorColor))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(4, geo.size.width * CGFloat(cost / max(maxCost, 0.0001))), height: 3)
                }
            }
            .frame(height: 3)
        }
    }

    private var decodedName: String {
        // ~/.claude/projects 下目录名是 URL 编码的路径，解码后取最后一段
        let decoded = name.removingPercentEncoding ?? name
        return decoded.components(separatedBy: "/").last ?? decoded
    }
}

// MARK: - 子组件：最近记录行

private struct RecentEntryRow: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 6) {
            // 模型标签
            Text(shortModel)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(4)

            // Token 摘要
            Text("↓\(MonitoringViewModel.formatTokens(entry.inputTokens)) ↑\(MonitoringViewModel.formatTokens(entry.outputTokens))")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            // 成本
            Text(MonitoringViewModel.formatCost(entry.costUsd))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(entry.costUsd > 0 ? .primary : .secondary)

            // 时间
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var shortModel: String {
        // 模型名称简化显示：claude-sonnet-4-6-20251001 → sonnet
        // 按优先级匹配（从新模型到旧模型）
        let m = entry.model.lowercased()

        // 1. Mythos 系列（最高级模型）
        if m.contains("mythos") { return "mythos" }

        // 2. Fable 系列
        if m.contains("fable") { return "fable" }

        // 3. Opus 系列
        if m.contains("opus") { return "opus" }

        // 4. Sonnet 系列
        if m.contains("sonnet") { return "sonnet" }

        // 5. Haiku 系列
        if m.contains("haiku") { return "haiku" }

        // 6. 无法识别时：如果模型名以 "claude-" 开头，尝试提取中间部分
        // 例如："claude-v3" → "v3", "claude-" → "claude"
        if m.hasPrefix("claude-") {
            let suffix = m.dropFirst(7) // 去掉 "claude-"
            if suffix.isEmpty {
                return "claude"
            }
            // 提取有意义的标识符（最多10字符）
            let identifier = String(suffix.prefix(10))
            return identifier
        }

        // 7. 其他情况：显示完整模型名（最多12字符）
        return String(entry.model.prefix(12))
    }
}

// MARK: - 子组件：Agent 行（Agents Section 中的每一行）

private struct AgentRow: View {
    let agentData: AllAgentData
    let totalCost: Double      // 所有 Agent 今日成本之和（用于计算占比）
    let isExpanded: Bool
    let onToggle: () -> Void

    private var kind: AgentKind { agentData.agentKind }
    private var isActive: Bool { agentData.todayCost > 0 }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // 活跃状态指示圆点
                Circle()
                    .fill(isActive ? kind.color : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)

                // Agent 名称
                Text(kind.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(minWidth: 80, alignment: .leading)

                // 今日成本
                Text(MonitoringViewModel.formatCost(agentData.todayCost))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .frame(width: 52, alignment: .trailing)

                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.separatorColor))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(kind.color.opacity(isActive ? 1.0 : 0.3))
                            .frame(width: max(0, geo.size.width * CGFloat(agentData.todayCost / totalCost)), height: 4)
                    }
                }
                .frame(height: 4)

                // 展开/折叠指示
                Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                    .imageScale(.small)
                    .foregroundColor(.secondary)
                    .frame(width: 14)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isExpanded ? Color(.controlBackgroundColor) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - 子组件：章节标题

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - 子组件：30天每日成本柱状图

private struct DailyBarChart: View {
    let history: [(day: Date, cost: Double, tokens: Int)]

    var body: some View {
        if history.isEmpty {
            Text(L10n.shared.str(.noChartData))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            Chart(history, id: \.day) { item in
                BarMark(
                    x: .value(L10n.shared.axisDate, item.day, unit: .day),
                    y: .value(L10n.shared.axisCost, item.cost)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "$%.2f", v))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(Color(.controlBackgroundColor))
            }
        }
    }
}

