//
//  StatusBarView.swift
//  ClaudeMonitor
//
//  菜单栏点击后弹出的详情面板
//

import SwiftUI

struct StatusBarView: View {
    @Environment(MonitoringViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部标题栏 ──────────────────────────────────────
            headerBar

            Divider()

            // ── 核心统计卡片 ────────────────────────────────────
            statsGrid
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Divider()
                .padding(.vertical, 8)

            // ── 项目成本排行 ────────────────────────────────────
            projectSection
                .padding(.horizontal, 16)

            Divider()
                .padding(.vertical, 8)

            // ── 最近记录（最新 5 条）───────────────────────────
            recentSection
                .padding(.horizontal, 16)

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
            Text("Claude 用量监控")
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
        let data = viewModel.monitoringData
        let rate = viewModel.tokenRate
        return VStack(spacing: 8) {
            // ── 实时速率行（仿 iStat）────────────────────────────
            RateBar(rate: rate)

            // ── 统计卡片（2x2）──────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCell(
                    icon: "dollarsign.circle.fill",
                    iconColor: .green,
                    label: "总成本",
                    value: MonitoringViewModel.formatCost(data.totalCost)
                )
                StatCell(
                    icon: "arrow.down.circle.fill",
                    iconColor: .blue,
                    label: "输入 Tokens",
                    value: MonitoringViewModel.formatTokens(data.totalInputTokens)
                )
                StatCell(
                    icon: "arrow.up.circle.fill",
                    iconColor: .orange,
                    label: "输出 Tokens",
                    value: MonitoringViewModel.formatTokens(data.totalOutputTokens)
                )
                StatCell(
                    icon: "memorychip.fill",
                    iconColor: .purple,
                    label: "缓存读取",
                    value: MonitoringViewModel.formatTokens(data.totalCacheReadTokens)
                )
            }
        }
    }

    // MARK: - 项目成本排行

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "项目成本 TOP 5", systemImage: "folder.fill")

            if viewModel.monitoringData.projectCosts.isEmpty {
                Text("暂无项目数据")
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
            SectionHeader(title: "最近记录", systemImage: "clock.fill")

            let entries = viewModel.monitoringData.recentEntries.suffix(5).reversed()
            if entries.isEmpty {
                Text("暂无记录")
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

    // MARK: - 底部工具栏

    private var bottomBar: some View {
        HStack {
            // 错误提示
            if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .imageScale(.small)
                Text(error)
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

            // 退出按钮
            Button("退出") {
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
                    Text("输入")
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
                    Text("输出")
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
        // claude-3-5-sonnet-20241022 → sonnet
        let m = entry.model.lowercased()
        if m.contains("opus") { return "opus" }
        if m.contains("sonnet") { return "sonnet" }
        if m.contains("haiku") { return "haiku" }
        return String(entry.model.prefix(6))
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

