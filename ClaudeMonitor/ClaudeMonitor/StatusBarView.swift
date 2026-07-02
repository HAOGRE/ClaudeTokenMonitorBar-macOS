import SwiftUI
import Charts

// MARK: - Theme & Colors

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light) ?? NSColor.black
        }))
    }
    
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }))
    }
}

struct Theme {
    let isDark: Bool

    func dynamic(light: String, dark: String) -> Color {
        return Color(nsColor: NSColor(hex: isDark ? dark : light) ?? .black)
    }
    func dynamic(light: NSColor, dark: NSColor) -> Color {
        return Color(nsColor: isDark ? dark : light)
    }

    var bg: Color { dynamic(light: "#e8efeb", dark: "#111315") }
    var panelBg: Color { dynamic(light: "#fcfdfc", dark: "#202226") }
    var softCardBg: Color { dynamic(light: "#eef1ef", dark: "#2a2d31") }
    var panelBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.06), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.08)) }

    var primaryGreen: Color { dynamic(light: "#4b9665", dark: "#70b687") }
    var chartGreen: Color { dynamic(light: "#3f8758", dark: "#63a978") }
    var lightGreen: Color { dynamic(light: "#a7dbc0", dark: "#8ed8ab") }

    var textMain: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.94), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.88)) }
    var textSecondary: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.48), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.48)) }
    var textTertiary: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.30), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.28)) }
    var separator: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.055), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)) }
    var track: Color { dynamic(light: "#ecf0ed", dark: "#2d3034") }

    var segBg: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.055), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.065)) }
    var segBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.055), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.08)) }
    var segOnBg: Color { dynamic(light: NSColor(red: 1, green: 1, blue: 1, alpha: 0.95), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.14)) }
    var segOnText: Color { dynamic(light: "#252a27", dark: "#f1f3f1") }
    var segOffText: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.48), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.50)) }

    var gridEmpty: Color { dynamic(light: "#e0e8e2", dark: "#2f3935") }
    var gridLevel1: Color { dynamic(light: "#c8e0d0", dark: "#345941") }
    var gridLevel2: Color { dynamic(light: "#9fcfae", dark: "#477c5a") }
    var gridLevel3: Color { dynamic(light: "#6fb584", dark: "#5ea872") }
    var gridLevel4: Color { dynamic(light: "#3f8758", dark: "#78c18e") }
    
    var palette: [Color] {
        [
            chartGreen,
            lightGreen,
            dynamic(light: "#50605a", dark: "#5f6964"),
            dynamic(light: "#73bf8a", dark: "#7ed29c"),
            dynamic(light: "#b8e2c9", dark: "#a8dfbd")
        ]
    }
}

private enum DashboardLayout {
    static let panelWidth: CGFloat = 400
    static let panelHeight: CGFloat = 760
    static let panelRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let sectionTitleSize: CGFloat = 10.5
    static let rowLabelWidth: CGFloat = 116
    static let rowValueWidth: CGFloat = 50
    static let rowPercentWidth: CGFloat = 32
    static let barHeight: CGFloat = 5
    static let heatmapCell: CGFloat = 9
    static let heatmapGap: CGFloat = 3
    static let heatmapWeeks: Int = 26
    static let heatmapRows: Int = 7
}

struct StatusBarView: View {
    @Environment(MonitoringViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    @State private var selectedPeriod: Int = 1 // 0: Day, 1: Week, 2: Month
    @State private var showingSettings = false
    private var settings: AppSettings { AppSettings.shared }
    private var l10n: L10n { L10n.shared }
    private var currentReport: PeriodReport {
        let dashboard = viewModel.monitoringData.dashboard
        switch selectedPeriod {
        case 0: return dashboard.day
        case 1: return dashboard.week
        case 2: return dashboard.month
        default: return dashboard.week
        }
    }
    
    private var trendSubtitle: String {
        switch selectedPeriod {
        case 0: return "today"
        case 1: return "last 7 days"
        default: return "this month"
        }
    }
    
    var body: some View {
        Group {
            if showingSettings {
                SettingsView { showingSettings = false }
            } else {
                mainView
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DashboardLayout.sectionSpacing) {
                    heroSection
                    splitBarSection
                    barChartSection

                    sectionDivider
                    tokensByModelSection

                    sectionDivider
                    costByModelSection

                    sectionDivider
                    trendCardsSection

                    if settings.showProjectSection {
                        sectionDivider
                        projectsSection
                    }

                    if settings.showRecentSection {
                        sectionDivider
                        skillsSection
                    }

                    sectionDivider
                    heatmapSection

                    bottomBar
                }
                .padding(.horizontal, DashboardLayout.horizontalPadding)
                .padding(.bottom, DashboardLayout.horizontalPadding)
            }
        }
        .frame(width: DashboardLayout.panelWidth, height: DashboardLayout.panelHeight)
        .background(theme.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DashboardLayout.panelRadius, style: .continuous)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(theme.primaryGreen)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.primaryGreen, lineWidth: 1.4)
                    )
                Text("Tokenscope")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textMain)
            }
            .frame(minWidth: 116, alignment: .leading)

            Spacer()

            HStack(spacing: 2) {
                PeriodButton(title: "Day", isSelected: selectedPeriod == 0) { selectedPeriod = 0 }
                PeriodButton(title: "Week", isSelected: selectedPeriod == 1) { selectedPeriod = 1 }
                PeriodButton(title: "Month", isSelected: selectedPeriod == 2) { selectedPeriod = 2 }
            }
            .padding(2)
            .background(theme.segBg)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.segBorder, lineWidth: 1)
            )

            HStack(spacing: 4) {
                headerIconButton(
                    systemName: "square.and.arrow.up",
                    help: "Copy panel snapshot",
                    action: copyPanelSnapshot
                )
            }
        }
        .padding(.horizontal, DashboardLayout.horizontalPadding)
        .padding(.top, DashboardLayout.horizontalPadding)
        .padding(.bottom, 9)
    }

    private func headerIconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .frame(width: 26, height: 26)
                .background(theme.segBg)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.segBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func copyPanelSnapshot() {
        guard let contentView = NSApp.keyWindow?.contentView else { return }
        let bounds = contentView.bounds
        guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        contentView.cacheDisplay(in: bounds, to: bitmap)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(height: 1)
    }
    
    private var heroSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOTAL TOKENS")
                        .sectionTitleFont()
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        let formatted = formatLargeNumber(currentReport.metrics.totalTokens)
                        Text(formatted.value)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .monospacedDigit()
                        Text(formatted.suffix)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        
                        let delta = currentReport.metrics.deltaTokens
                        HStack(spacing: 2) {
                            if delta == 0 {
                                Text("0%").font(.system(size: 9.5, weight: .bold))
                            } else {
                                Image(systemName: delta > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                    .font(.system(size: 7.5))
                                Text(formatDeltaPercent(delta))
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(theme.primaryGreen.opacity(0.15))
                        .foregroundColor(theme.primaryGreen)
                        .cornerRadius(4)
                        .padding(.bottom, 5)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Est. cost")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    Text(MonitoringViewModel.formatCost(currentReport.metrics.cost))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.primaryGreen)
                        .monospacedDigit()
                }
                .padding(.top, 18)
            }
        }
    }
    
    private var splitBarSection: some View {
        VStack(spacing: 7) {
            let total = max(1, currentReport.metrics.inputTokens + currentReport.metrics.outputTokens)
            let inRatio = Double(currentReport.metrics.inputTokens) / Double(total)
            let outRatio = Double(currentReport.metrics.outputTokens) / Double(total)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.track)
                    if currentReport.metrics.totalTokens > 0 {
                        HStack(spacing: 0) {
                            theme.chartGreen.frame(width: geo.size.width * CGFloat(inRatio))
                            theme.lightGreen.frame(width: geo.size.width * CGFloat(outRatio))
                        }
                        .cornerRadius(4)
                    }
                }
            }
            .frame(height: 7)
            
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle().fill(theme.chartGreen).frame(width: 7, height: 7)
                    Text("Input \(formatLargeNumberStr(currentReport.metrics.inputTokens))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(theme.lightGreen).frame(width: 7, height: 7)
                    Text("Output \(formatLargeNumberStr(currentReport.metrics.outputTokens))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
    }
    
    private var barChartSection: some View {
        VStack {
            Chart(currentReport.series) { item in
                BarMark(x: .value("Time", item.label), y: .value("Input", item.input))
                    .foregroundStyle(theme.chartGreen)
                BarMark(x: .value("Time", item.label), y: .value("Output", item.output))
                    .foregroundStyle(theme.lightGreen)
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(theme.separator)
                }
            }
            .frame(height: 104)
        }
    }
    
    private var tokensByModelSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TOKENS BY MODEL")
                .sectionTitleFont()
                .foregroundColor(theme.textSecondary)
            
            if currentReport.models.isEmpty {
                compactEmptyState("No usage in this period")
            } else {
                let total = max(1, currentReport.metrics.totalTokens)
                ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                    let pct = Double(model.tokens) / Double(total)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(theme.palette[index % theme.palette.count])
                            .frame(width: 7, height: 7)
                        Text(shortModelName(model.name))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .frame(width: DashboardLayout.rowLabelWidth, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous).fill(theme.track)
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous)
                                    .fill(theme.palette[index % theme.palette.count])
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: DashboardLayout.barHeight)
                        
                        Text(formatLargeNumberStr(model.tokens))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: DashboardLayout.rowValueWidth, alignment: .trailing)
                            .monospacedDigit()
                            
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textMain)
                            .frame(width: DashboardLayout.rowPercentWidth, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .frame(height: 22)
                }
            }
        }
    }
    
    private var costByModelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COST BY MODEL")
                .sectionTitleFont()
                .foregroundColor(theme.textSecondary)
            
            if currentReport.models.isEmpty {
                compactEmptyState("No model costs in this period")
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Chart {
                            ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                                SectorMark(
                                    angle: .value("Cost", model.cost),
                                    innerRadius: .ratio(0.7),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(theme.palette[index % theme.palette.count])
                            }
                        }
                        Text(MonitoringViewModel.formatCost(currentReport.metrics.cost))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .monospacedDigit()
                    }
                    .frame(width: 100, height: 100)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(theme.palette[index % theme.palette.count])
                                    .frame(width: 7, height: 7)
                                Text(shortModelName(model.name))
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.textMain)
                                    .lineLimit(1)
                                Spacer()
                                Text(MonitoringViewModel.formatCost(model.cost))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                                    .monospacedDigit()
                            }
                            .frame(height: 17)
                        }
                    }
                }
            }
        }
    }
    
    private var trendCardsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TrendCard(
                    title: "REQUESTS",
                    value: formatWholeNumber(currentReport.metrics.requests),
                    subtitle: "\(formatWholeNumber(currentReport.metrics.sessions)) sessions",
                    points: currentReport.reqTrend,
                    color: theme.primaryGreen
                )
                TrendCard(
                    title: "COST TREND",
                    value: MonitoringViewModel.formatCost(currentReport.metrics.cost),
                    subtitle: trendSubtitle,
                    points: currentReport.costTrend,
                    color: theme.primaryGreen
                )
            }

            if let v4 = viewModel.monitoringData.v4State?.limits?.five_hour {
                v4RateLimitsSection(fiveHour: v4)
            }
        }
    }

    private func v4RateLimitsSection(fiveHour: V4LimitDetail) -> some View {
        let used = fiveHour.tokens_used ?? 0
        let limit = max(fiveHour.token_limit ?? 1, 1)
        let percentage = fiveHour.used_percentage ?? (Double(used) / Double(limit) * 100)
        
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                Text("OFFICIAL RATE LIMITS (V4)")
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("5-Hour Window")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.1f", percentage))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(percentage > 90 ? .red : (percentage > 75 ? .orange : theme.textMain))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.separator)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(percentage > 90 ? Color.red : (percentage > 75 ? Color.orange : Color.blue))
                            .frame(width: max(0, geo.size.width * CGFloat(percentage / 100)), height: 6)
                    }
                }
                .frame(height: 6)
                
                if let resetsAt = fiveHour.resets_at {
                    HStack {
                        Spacer()
                        Text("Resets at \(resetsAt)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.softCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("MCP CALLS")
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(formatWholeNumber(currentReport.metrics.mcpCalls)) · \(currentReport.metrics.servers) servers")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
            }
            
            if currentReport.mcp.isEmpty {
                compactEmptyState("No MCP calls in this period")
            } else {
                let servers = currentReport.mcp.prefix(5)
                let maxCount = Double(servers.first?.count ?? 1)
                
                ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                    let pct = Double(server.count) / max(maxCount, 1)
                    HStack(spacing: 8) {
                        Text(server.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textMain)
                            .frame(width: DashboardLayout.rowLabelWidth, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous).fill(theme.track)
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous)
                                    .fill(theme.chartGreen)
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: DashboardLayout.barHeight)
                        
                        Text(formatCompactCount(server.count))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 42, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .frame(height: 20)
                    .help(server.name)
                }

                if currentReport.mcp.count > 5 {
                    Text("+\(currentReport.mcp.count - 5) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("SKILL CALLS")
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(formatWholeNumber(currentReport.metrics.skillCalls)) · \(currentReport.metrics.skills) skills")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
            }
            
            if currentReport.skills.isEmpty {
                compactEmptyState("No skill calls in this period")
            } else {
                let skills = currentReport.skills.prefix(5)
                let maxCount = Double(skills.first?.count ?? 1)
                
                ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                    let pct = Double(skill.count) / Double(max(maxCount, 1))
                    HStack(spacing: 8) {
                        Text(skill.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textMain)
                            .frame(width: DashboardLayout.rowLabelWidth, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous).fill(theme.track)
                                RoundedRectangle(cornerRadius: DashboardLayout.barHeight / 2, style: .continuous)
                                    .fill(theme.lightGreen)
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: DashboardLayout.barHeight)
                        
                        Text(formatCompactCount(skill.count))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 42, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .frame(height: 20)
                    .help(skill.name)
                }

                if currentReport.skills.count > 5 {
                    Text("+\(currentReport.skills.count - 5) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }
    
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("DAILY ACTIVITY")
                .sectionTitleFont()
                .foregroundColor(theme.textSecondary)

            let heatmap = viewModel.monitoringData.dashboard.heatmap
            if heatmap.isEmpty {
                compactEmptyState("No daily activity")
            } else {
                let weeks = heatmapWeeks(heatmap)
                let gridWidth = heatmapGridWidth(weekCount: weeks.count)
                VStack(alignment: .leading, spacing: 5) {
                    ZStack(alignment: .leading) {
                        ForEach(heatmapMonthMarkers(weeks)) { marker in
                            Text(marker.label)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.textTertiary)
                                .offset(x: CGFloat(marker.weekIndex) * (DashboardLayout.heatmapCell + DashboardLayout.heatmapGap))
                        }
                    }
                    .frame(width: gridWidth, height: 11, alignment: .leading)

                    HStack(alignment: .top, spacing: DashboardLayout.heatmapGap) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: DashboardLayout.heatmapGap) {
                                ForEach(0..<DashboardLayout.heatmapRows, id: \.self) { dayIndex in
                                    heatmapCell(dayIndex < week.count ? week[dayIndex] : nil)
                                }
                            }
                        }
                    }
                    .frame(width: gridWidth, alignment: .leading)

                    HStack(spacing: 4) {
                        Spacer()
                        Text("Less")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.trailing, 2)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(colorForLevel(level))
                                .frame(width: DashboardLayout.heatmapCell, height: DashboardLayout.heatmapCell)
                        }
                        Text("More")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.leading, 2)
                    }
                    .frame(width: gridWidth, alignment: .trailing)
                }
            }
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 10) {
            if viewModel.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).imageScale(.small)
                Text(l10n.str(.noDataError))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .foregroundColor(theme.textSecondary)
            .help("Settings")
            Button(l10n.str(.resetButton)) { viewModel.resetStats() }
                .font(.system(size: 11.5, weight: .semibold))
                .buttonStyle(.borderless)
                .foregroundColor(theme.textSecondary)
            Button(l10n.str(.quitButton)) { NSApplication.shared.terminate(nil) }
                .font(.system(size: 11.5, weight: .semibold))
                .buttonStyle(.borderless)
                .foregroundColor(theme.textSecondary)
        }
        .frame(height: 20)
    }
    
    // MARK: - Helpers

    private func compactEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textSecondary.opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
    }

    private func heatmapCell(_ day: HeatDay?) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(day.map { colorForLevel($0.level) } ?? Color.clear)
            .frame(width: DashboardLayout.heatmapCell, height: DashboardLayout.heatmapCell)
            .help(day.map(heatmapHelp) ?? "")
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1: return theme.gridLevel1
        case 2: return theme.gridLevel2
        case 3: return theme.gridLevel3
        case 4: return theme.gridLevel4
        default: return theme.gridEmpty
        }
    }
    
    private func shortModelName(_ full: String) -> String {
        let m = full.lowercased()
        if m.contains("mythos") { return "Claude Mythos" }
        if m.contains("fable") { return "Claude Fable" }
        if m.contains("opus") { return "Claude Opus" }
        if m.contains("sonnet") { return "Claude Sonnet" }
        if m.contains("haiku") { return "Claude Haiku" }
        if m.hasPrefix("claude-") { return "Claude " + String(m.dropFirst(7).prefix(6)).capitalized }
        return String(m.prefix(15))
    }
    
    private func formatLargeNumber(_ count: Int) -> (value: String, suffix: String) {
        if count == 0 {
            return ("0.00", "M")
        }
        if count >= 1_000_000 {
            return (String(format: "%.2f", Double(count) / 1_000_000), "M")
        } else if count >= 1_000 {
            return (String(format: "%.1f", Double(count) / 1_000), "K")
        }
        return ("\(count)", "")
    }
    
    private func formatLargeNumberStr(_ count: Int) -> String {
        let f = formatLargeNumber(count)
        return f.value + f.suffix
    }

    private func formatCompactCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatDeltaPercent(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 10 {
            return String(format: "%.0f%%", absValue)
        }
        return String(format: "%.1f%%", absValue)
    }

    private func formatWholeNumber(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func heatmapWeeks(_ heatmap: [HeatDay]) -> [[HeatDay?]] {
        let days = Array(heatmap.suffix(DashboardLayout.heatmapWeeks * DashboardLayout.heatmapRows))
        var weeks: [[HeatDay?]] = []
        var index = 0
        while index < days.count {
            let end = min(index + DashboardLayout.heatmapRows, days.count)
            var week = days[index..<end].map(Optional.some)
            if week.count < DashboardLayout.heatmapRows {
                week.append(contentsOf: Array(repeating: nil, count: DashboardLayout.heatmapRows - week.count))
            }
            weeks.append(week)
            index += DashboardLayout.heatmapRows
        }
        return weeks
    }

    private func heatmapGridWidth(weekCount: Int) -> CGFloat {
        guard weekCount > 0 else { return 0 }
        return CGFloat(weekCount) * DashboardLayout.heatmapCell + CGFloat(max(weekCount - 1, 0)) * DashboardLayout.heatmapGap
    }

    private func heatmapMonthMarkers(_ weeks: [[HeatDay?]]) -> [HeatmapMonthMarker] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"

        var markers: [HeatmapMonthMarker] = []
        var lastMonth: Int?
        let calendar = Calendar.current

        for (weekIndex, week) in weeks.enumerated() {
            guard let day = week.compactMap({ $0 }).first else { continue }
            let month = calendar.component(.month, from: day.date)
            if month != lastMonth {
                markers.append(HeatmapMonthMarker(weekIndex: weekIndex, label: formatter.string(from: day.date)))
                lastMonth = month
            }
        }

        return markers
    }

    private func heatmapHelp(for day: HeatDay) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: day.date)): \(formatWholeNumber(day.tokens)) tokens"
    }
}

// MARK: - Subcomponents

private struct HeatmapMonthMarker: Identifiable {
    let weekIndex: Int
    let label: String

    var id: String { "\(weekIndex)-\(label)" }
}

private extension Text {
    func sectionTitleFont() -> some View {
        self
            .font(.system(size: DashboardLayout.sectionTitleSize, weight: .bold))
    }
}

private struct PeriodButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? theme.segOnText : theme.segOffText)
                .frame(width: 42, height: 22)
                .background(isSelected ? theme.segOnBg : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: isSelected ? Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10) : Color.clear, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct TrendCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    let title: String
    let value: String
    let subtitle: String
    let points: [Double]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .sectionTitleFont()
                        .foregroundColor(theme.textSecondary)
                    Text(value)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(title == "COST TREND" ? theme.primaryGreen : theme.textMain)
                        .monospacedDigit()
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                
                if points.count > 1 {
                    SparklineView(points: points, color: color)
                        .frame(width: 48, height: 24)
                } else {
                    SparklineView(points: [0, 0], color: color)
                        .frame(width: 48, height: 24)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(theme.softCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SparklineView: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    let points: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let maxVal = points.max() ?? 1
                let minVal = points.min() ?? 0
                let range = maxVal - minVal
                
                let stepX = geo.size.width / CGFloat(points.count - 1)
                
                for (index, value) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y: CGFloat
                    if range == 0 {
                        y = geo.size.height / 2
                    } else {
                        y = geo.size.height - (CGFloat(value - minVal) / CGFloat(range)) * geo.size.height
                    }
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
