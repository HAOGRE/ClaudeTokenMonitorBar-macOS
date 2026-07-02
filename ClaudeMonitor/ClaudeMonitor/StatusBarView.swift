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

    var bg: Color { dynamic(light: "#edf2ef", dark: "#111417") }
    var panelBg: Color { dynamic(light: "#fbfbfa", dark: "#1d2023") }
    var softCardBg: Color { dynamic(light: "#f0f1f0", dark: "#292d31") }
    var panelBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.08), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.08)) }
    
    var primaryGreen: Color { dynamic(light: "#178a55", dark: "#27b06e") }
    var chartGreen: Color { dynamic(light: "#178a55", dark: "#27b06e") }
    var lightGreen: Color { dynamic(light: "#8fd9b4", dark: "#5fcf9c") }
    
    var textMain: Color { dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.94), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.94)) }
    var textSecondary: Color { dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.48), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.46)) }
    var textTertiary: Color { dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.32), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.28)) }
    var separator: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.065), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.055)) }
    var track: Color { dynamic(light: "#eceeed", dark: "#2a2e31") }
    
    var segBg: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.05), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)) }
    var segBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.07), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.09)) }
    var segOnBg: Color { dynamic(light: NSColor(red: 1, green: 1, blue: 1, alpha: 1.0), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.15)) }
    var segOnText: Color { dynamic(light: "#111111", dark: "#ffffff") }
    var segOffText: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55)) }
    
    var gridEmpty: Color { dynamic(light: "#e8ebe8", dark: "#30363a") }
    var gridLevel1: Color { dynamic(light: "#ccebdc", dark: "#284f3b") }
    var gridLevel2: Color { dynamic(light: "#9ed9bd", dark: "#33734f") }
    var gridLevel3: Color { dynamic(light: "#61be87", dark: "#4ea96d") }
    var gridLevel4: Color { dynamic(light: "#3f8f5a", dark: "#67c583") }
    
    var palette: [Color] {
        [
            chartGreen,
            lightGreen,
            dynamic(light: "#aeb8b2", dark: "#5a6660"),
            dynamic(light: "#70c39a", dark: "#40be84"),
            dynamic(light: "#a0e0c0", dark: "#7ce3b1")
        ]
    }
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
        case 1: return "this week"
        default: return "this month"
        }
    }
    
    var body: some View {
        if showingSettings {
            SettingsView { showingSettings = false }
        } else {
            mainView
        }
    }
    
    private var mainView: some View {
        ZStack {
            theme.bg

            VStack(spacing: 0) {
                headerSection

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
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
                            recentSection
                        }

                        sectionDivider
                        heatmapSection

                        bottomBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(theme.panelBg)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.panelBorder, lineWidth: 1)
            )
            .padding(14)
        }
        .frame(width: 400, height: 760)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.primaryGreen)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(theme.primaryGreen, lineWidth: 1.5)
                    )
                Text("Tokenscope")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textMain)
            }

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
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(height: 1)
    }
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL TOKENS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        let formatted = formatLargeNumber(currentReport.metrics.totalTokens)
                        Text(formatted.value)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .monospacedDigit()
                        Text(formatted.suffix)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                        
                        HStack(spacing: 2) {
                            if currentReport.metrics.totalTokens == 0 {
                                Text("0%").font(.system(size: 10, weight: .bold))
                            } else {
                                Image(systemName: "arrowtriangle.up.fill").font(.system(size: 8))
                                Text("14%").font(.system(size: 10, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(theme.primaryGreen.opacity(0.15))
                        .foregroundColor(theme.primaryGreen)
                        .cornerRadius(4)
                        .padding(.bottom, 8)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. cost")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    Text(MonitoringViewModel.formatCost(currentReport.metrics.cost))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryGreen)
                        .monospacedDigit()
                }
                .padding(.top, 14)
            }
        }
    }
    
    private var splitBarSection: some View {
        VStack(spacing: 8) {
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
            .frame(height: 8)
            
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(theme.chartGreen).frame(width: 8, height: 8)
                    Text("Input \(formatLargeNumberStr(currentReport.metrics.inputTokens))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(theme.lightGreen).frame(width: 8, height: 8)
                    Text("Output \(formatLargeNumberStr(currentReport.metrics.outputTokens))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
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
            .frame(height: 112)
        }
    }
    
    private var tokensByModelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOKENS BY MODEL")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary)
            
            if currentReport.models.isEmpty {
                Text("No usage in this period")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                let total = max(1, currentReport.metrics.totalTokens)
                ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                    let pct = Double(model.tokens) / Double(total)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(theme.palette[index % theme.palette.count])
                            .frame(width: 8, height: 8)
                        Text(shortModelName(model.name))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.textMain)
                            .frame(width: 112, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(theme.track)
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(theme.palette[index % theme.palette.count])
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: 5)
                        
                        Text(formatLargeNumberStr(model.tokens))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                            
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textMain)
                            .frame(width: 35, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
    
    private var costByModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COST BY MODEL")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary)
            
            if currentReport.models.isEmpty {
                Text("-")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 18) {
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
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .monospacedDigit()
                    }
                    .frame(width: 104, height: 104)
                    
                    VStack(spacing: 7) {
                        ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(theme.palette[index % theme.palette.count])
                                    .frame(width: 8, height: 8)
                                Text(shortModelName(model.name))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.textMain)
                                    .lineLimit(1)
                                Spacer()
                                Text(MonitoringViewModel.formatCost(model.cost))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var trendCardsSection: some View {
        VStack(spacing: 12) {
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
                    .font(.system(size: 11, weight: .bold))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MCP CALLS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                let total = currentReport.projects.reduce(0) { $0 + $1.count }
                Text("\(formatWholeNumber(total)) · \(currentReport.projects.count) servers")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
            }
            
            let projects = currentReport.projects.prefix(5)
            let maxCount = Double(projects.first?.count ?? 1)
            
            ForEach(Array(projects.enumerated()), id: \.element.id) { index, proj in
                let pct = Double(proj.count) / max(maxCount, 1)
                HStack(spacing: 8) {
                    let decoded = proj.name.removingPercentEncoding ?? proj.name
                    Text(decoded.components(separatedBy: "/").last ?? decoded)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textMain)
                        .frame(width: 112, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(theme.track)
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(theme.chartGreen)
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 5)
                    
                    Text(formatCompactCount(proj.count))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 42, alignment: .trailing)
                        .monospacedDigit()
                }
                .help(proj.name)
            }

            if currentReport.projects.count > 5 {
                Text("+\(currentReport.projects.count - 5) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SKILL CALLS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                let total = viewModel.monitoringData.recentEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
                Text("\(formatCompactCount(total)) · \(viewModel.monitoringData.recentEntries.count) latest")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .monospacedDigit()
            }
            
            let entries = viewModel.monitoringData.recentEntries.suffix(5).reversed()
            let maxTokens = entries.map { $0.inputTokens + $0.outputTokens }.max() ?? 1
            
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let tokens = entry.inputTokens + entry.outputTokens
                let pct = Double(tokens) / Double(max(maxTokens, 1))
                HStack(spacing: 8) {
                    Text(shortModelName(entry.model))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textMain)
                        .frame(width: 112, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(theme.track)
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(theme.lightGreen)
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 5)
                    
                    Text(formatCompactCount(tokens))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 42, alignment: .trailing)
                        .monospacedDigit()
                }
                .help("\(entry.model) · \(formatWholeNumber(tokens)) tokens")
            }
        }
    }
    
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DAILY ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary)

            let heatmap = viewModel.monitoringData.dashboard.heatmap
            if heatmap.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(heatmapMonthLabels(heatmap), id: \.self) { month in
                            Text(month)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        let rows = Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7)
                        LazyHGrid(rows: rows, spacing: 3) {
                            ForEach(heatmap) { day in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(colorForLevel(day.level))
                                    .frame(width: 10, height: 10)
                                    .help(heatmapHelp(for: day))
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Spacer()
                        Text("Less")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.trailing, 2)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(colorForLevel(level))
                                .frame(width: 10, height: 10)
                        }
                        Text("More")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.leading, 2)
                    }
                }
            }
        }
    }
    
    private var bottomBar: some View {
        HStack {
            if viewModel.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).imageScale(.small)
                Text(l10n.str(.noDataError)).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Button { showingSettings = true } label: { Image(systemName: "gearshape").imageScale(.small) }.buttonStyle(.borderless).foregroundColor(.secondary)
            Button(l10n.str(.resetButton)) { viewModel.resetStats() }.font(.caption).buttonStyle(.borderless).foregroundColor(.secondary)
            Button(l10n.str(.quitButton)) { NSApplication.shared.terminate(nil) }.font(.caption).buttonStyle(.borderless).foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helpers
    
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

    private func formatWholeNumber(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func heatmapMonthLabels(_ heatmap: [HeatDay]) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"

        var labels: [String] = []
        var lastMonth: Int?
        let calendar = Calendar.current

        for day in heatmap {
            let month = calendar.component(.month, from: day.date)
            if month != lastMonth {
                labels.append(formatter.string(from: day.date))
                lastMonth = month
            }
        }

        return labels.isEmpty ? [""] : labels
    }

    private func heatmapHelp(for day: HeatDay) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: day.date)): \(formatWholeNumber(day.tokens)) tokens"
    }
}

// MARK: - Subcomponents

private struct PeriodButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? theme.segOnText : theme.segOffText)
                .frame(width: 44, height: 22)
                .background(isSelected ? theme.segOnBg : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.clear, radius: 1, y: 1)
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
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(title == "COST TREND" ? theme.primaryGreen : theme.textMain)
                        .monospacedDigit()
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                
                // Sparkline
                if points.count > 1 {
                    SparklineView(points: points, color: color)
                        .frame(width: 50, height: 24)
                } else {
                    SparklineView(points: [0, 0], color: color)
                        .frame(width: 50, height: 24)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72)
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
