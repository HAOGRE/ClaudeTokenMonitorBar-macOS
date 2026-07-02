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

struct TokenScopeTheme {
    static let bg = Color.dynamic(light: "#ffffff", dark: "#1f2226")
    static let cardBg = Color.dynamic(light: "#ffffff", dark: "#1f2226") // Same as bg but we use a border or shadow if needed
    static let cardBorder = Color.dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.08), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    
    static let primaryGreen = Color.dynamic(light: "#178a55", dark: "#27b06e")
    static let chartGreen = Color.dynamic(light: "#178a55", dark: "#27b06e")
    static let lightGreen = Color.dynamic(light: "#8fd9b4", dark: "#5fcf9c")
    
    static let textMain = Color.dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.94), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.94))
    static let textSecondary = Color.dynamic(light: NSColor(red: 17/255, green: 22/255, blue: 19/255, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.52))
    static let separator = Color.dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.06), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    
    static let segBg = Color.dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.05), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    static let segBorder = Color.dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.07), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.09))
    static let segOnBg = Color.dynamic(light: NSColor(red: 1, green: 1, blue: 1, alpha: 1.0), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    static let segOnText = Color.dynamic(light: "#111111", dark: "#ffffff")
    static let segOffText = Color.dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.5), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55))
    
    // Model colors
    static let palette: [Color] = [
        chartGreen,
        lightGreen,
        Color.dynamic(light: "#aeb8b2", dark: "#5a6660"),
        Color.dynamic(light: "#70c39a", dark: "#40be84"),
        Color.dynamic(light: "#a0e0c0", dark: "#7ce3b1")
    ]
}

struct StatusBarView: View {
    @Environment(MonitoringViewModel.self) private var viewModel
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
    
    private var periodString: String {
        switch selectedPeriod {
        case 0: return "Today"
        case 1: return "This Week"
        default: return "This Month"
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
        VStack(spacing: 0) {
            headerSection
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // 2. Hero (Total Tokens & Cost)
                    heroSection
                    
                    // 3. Split Bar
                    splitBarSection
                    
                    // 4. Bar Chart
                    barChartSection
                    
                    Divider().background(TokenScopeTheme.separator)
                    
                    // 5. Tokens by Model
                    tokensByModelSection
                    
                    Divider().background(TokenScopeTheme.separator)
                    
                    // 6. Cost by Model
                    costByModelSection
                    
                    Divider().background(TokenScopeTheme.separator)
                    
                    // 7. Request & Cost Trend Cards
                    trendCardsSection
                    
                    Divider().background(TokenScopeTheme.separator)
                    
                    // 8. Projects (MCP Calls style)
                    if settings.showProjectSection {
                        projectsSection
                    }
                    
                    // 9. Recent (Skill Calls style)
                    if settings.showRecentSection {
                        recentSection
                    }
                    
                    // 10. Daily Activity (Heatmap)
                    if settings.showChartSection {
                        heatmapSection
                    }
                    
                    bottomBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 400, height: 750)
        .background(TokenScopeTheme.bg)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(TokenScopeTheme.primaryGreen)
                        .font(.system(size: 18))
                    Text("Tokenscope")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(TokenScopeTheme.textMain)
                }
                
                Spacer()
                
                // Custom Segmented Control
                HStack(spacing: 2) {
                    PeriodButton(title: "Day", isSelected: selectedPeriod == 0) { selectedPeriod = 0 }
                    PeriodButton(title: "Week", isSelected: selectedPeriod == 1) { selectedPeriod = 1 }
                    PeriodButton(title: "Month", isSelected: selectedPeriod == 2) { selectedPeriod = 2 }
                }
                .padding(2)
                .background(TokenScopeTheme.segBg)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopeTheme.segBorder, lineWidth: 1))
                
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "display")
                            .font(.system(size: 14))
                            .foregroundColor(TokenScopeTheme.segOffText)
                            .frame(width: 26, height: 26)
                            .background(TokenScopeTheme.segBg)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenScopeTheme.segBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                    
                    Button(action: {}) {
                        Image(systemName: "camera")
                            .font(.system(size: 14))
                            .foregroundColor(TokenScopeTheme.segOffText)
                            .frame(width: 26, height: 26)
                            .background(TokenScopeTheme.segBg)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenScopeTheme.segBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Divider().background(TokenScopeTheme.separator)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL TOKENS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        let formatted = formatLargeNumber(currentReport.metrics.totalTokens)
                        Text(formatted.value)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(TokenScopeTheme.textMain)
                        Text(formatted.suffix)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(TokenScopeTheme.textSecondary)
                        
                        // Badge
                        HStack(spacing: 2) {
                            if currentReport.metrics.totalTokens == 0 {
                                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 8))
                                Text("100%").font(.system(size: 10, weight: .bold))
                            } else {
                                Image(systemName: "arrowtriangle.up.fill").font(.system(size: 8))
                                Text("14%").font(.system(size: 10, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(TokenScopeTheme.primaryGreen.opacity(0.15))
                        .foregroundColor(TokenScopeTheme.primaryGreen)
                        .cornerRadius(4)
                        .padding(.bottom, 8)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. cost")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                    Text(MonitoringViewModel.formatCost(currentReport.metrics.cost))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TokenScopeTheme.primaryGreen)
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
                    RoundedRectangle(cornerRadius: 4).fill(TokenScopeTheme.separator)
                    if currentReport.metrics.totalTokens > 0 {
                        HStack(spacing: 0) {
                            TokenScopeTheme.chartGreen.frame(width: geo.size.width * CGFloat(inRatio))
                            TokenScopeTheme.lightGreen.frame(width: geo.size.width * CGFloat(outRatio))
                        }
                        .cornerRadius(4)
                    }
                }
            }
            .frame(height: 8)
            
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(TokenScopeTheme.chartGreen).frame(width: 8, height: 8)
                    Text("Input \(formatLargeNumberStr(currentReport.metrics.inputTokens))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(TokenScopeTheme.lightGreen).frame(width: 8, height: 8)
                    Text("Output \(formatLargeNumberStr(currentReport.metrics.outputTokens))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                }
                Spacer()
                Text("0% cached")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(TokenScopeTheme.textSecondary.opacity(0.6))
            }
        }
    }
    
    private var barChartSection: some View {
        VStack {
            Chart(currentReport.series) { item in
                BarMark(x: .value("Time", item.label), y: .value("Input", item.input))
                    .foregroundStyle(TokenScopeTheme.chartGreen)
                BarMark(x: .value("Time", item.label), y: .value("Output", item.output))
                    .foregroundStyle(TokenScopeTheme.lightGreen)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TokenScopeTheme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(TokenScopeTheme.separator)
                }
            }
            .frame(height: 120)
        }
    }
    
    private var tokensByModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOKENS BY MODEL")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(TokenScopeTheme.textSecondary)
            
            if currentReport.models.isEmpty {
                Text("No usage in this period")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(TokenScopeTheme.textSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                let total = max(1, currentReport.metrics.totalTokens)
                ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                    let pct = Double(model.tokens) / Double(total)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(TokenScopeTheme.palette[index % TokenScopeTheme.palette.count])
                            .frame(width: 8, height: 8)
                        Text(shortModelName(model.name))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)
                        
                        // Mini Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(TokenScopeTheme.separator)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(TokenScopeTheme.palette[index % TokenScopeTheme.palette.count])
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: 4)
                        
                        Text(formatLargeNumberStr(model.tokens))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TokenScopeTheme.textSecondary)
                            .frame(width: 45, alignment: .trailing)
                            
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    private var costByModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COST BY MODEL")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(TokenScopeTheme.textSecondary)
            
            if currentReport.models.isEmpty {
                Text("-")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(TokenScopeTheme.textSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 20) {
                    // Donut
                    ZStack {
                        Chart(currentReport.models.prefix(5)) { model in
                            SectorMark(
                                angle: .value("Cost", model.cost),
                                innerRadius: .ratio(0.7),
                                angularInset: 1.5
                            )
                            .foregroundStyle(model.color)
                        }
                        // Center text
                        Text(MonitoringViewModel.formatCost(currentReport.metrics.cost))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(width: 100, height: 100)
                    
                    // List
                    VStack(spacing: 8) {
                        ForEach(Array(currentReport.models.prefix(5).enumerated()), id: \.element.id) { index, model in
                            HStack {
                                Circle()
                                    .fill(TokenScopeTheme.palette[index % TokenScopeTheme.palette.count])
                                    .frame(width: 8, height: 8)
                                Text(shortModelName(model.name))
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(MonitoringViewModel.formatCost(model.cost))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(TokenScopeTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var trendCardsSection: some View {
        VStack(spacing: 16) {
            // The 4 items
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    StatItem(icon: "dollarsign", color: .green, title: "\(periodString)'s Cost", value: MonitoringViewModel.formatCost(currentReport.metrics.cost))
                    StatItem(icon: "arrow.down", color: .blue, title: "Input Tokens", value: MonitoringViewModel.formatTokens(currentReport.metrics.inputTokens))
                }
                HStack(spacing: 16) {
                    StatItem(icon: "arrow.up", color: .orange, title: "Output Tokens", value: MonitoringViewModel.formatTokens(currentReport.metrics.outputTokens))
                    StatItem(icon: "memorychip", color: .purple, title: "Cache Read", value: MonitoringViewModel.formatTokens(currentReport.metrics.cacheTokens))
                }
            }
            
            if let v4 = viewModel.monitoringData.v4State?.limits?.five_hour {
                Divider().background(TokenScopeTheme.separator)
                v4RateLimitsSection(fiveHour: v4)
            }
        }
        .padding(16)
        .background(TokenScopeTheme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TokenScopeTheme.separator, lineWidth: 1))
        .cornerRadius(12)
    }

    private func v4RateLimitsSection(fiveHour: V4LimitDetail) -> some View {
        let used = fiveHour.tokens_used ?? 0
        let limit = max(fiveHour.token_limit ?? 1, 1)
        let percentage = fiveHour.used_percentage ?? (Double(used) / Double(limit) * 100)
        
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 14))
                    .foregroundColor(TokenScopeTheme.textSecondary)
                Text("OFFICIAL RATE LIMITS (V4)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(TokenScopeTheme.textSecondary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("5-Hour Window")
                        .font(.system(size: 12))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.1f", percentage))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(percentage > 90 ? .red : (percentage > 75 ? .orange : TokenScopeTheme.textMain))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TokenScopeTheme.separator)
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
                            .foregroundColor(TokenScopeTheme.textSecondary)
                    }
                }
            }
        }
    }
    
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROJECT CALLS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(TokenScopeTheme.textSecondary)
                Spacer()
                Text("\(currentReport.metrics.requests) · \(currentReport.projects.count) projects")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TokenScopeTheme.textSecondary)
            }
            
            let projects = currentReport.projects.prefix(5)
            let maxCount = Double(projects.first?.count ?? 1)
            
            ForEach(Array(projects.enumerated()), id: \.element.id) { index, proj in
                let pct = Double(proj.count) / max(maxCount, 1)
                HStack(spacing: 8) {
                    let decoded = proj.name.removingPercentEncoding ?? proj.name
                    Text(decoded.components(separatedBy: "/").last ?? decoded)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(TokenScopeTheme.separator)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(TokenScopeTheme.chartGreen)
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(proj.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT CALLS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(TokenScopeTheme.textSecondary)
                Spacer()
                Text("\(viewModel.monitoringData.recentEntries.count) latest")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TokenScopeTheme.textSecondary)
            }
            
            let entries = viewModel.monitoringData.recentEntries.suffix(5).reversed()
            let maxTokens = entries.map { $0.inputTokens + $0.outputTokens }.max() ?? 1
            
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let tokens = entry.inputTokens + entry.outputTokens
                let pct = Double(tokens) / Double(max(maxTokens, 1))
                HStack(spacing: 8) {
                    Text(shortModelName(entry.model))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(TokenScopeTheme.separator)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(TokenScopeTheme.lightGreen)
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(tokens)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TokenScopeTheme.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
    
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(TokenScopeTheme.textSecondary)
            
            let heatmap = viewModel.monitoringData.dashboard.heatmap
            if heatmap.isEmpty {
                Text("No data").font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    let columns = Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7)
                    LazyHGrid(rows: columns, spacing: 3) {
                        ForEach(heatmap) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForLevel(day.level))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .frame(height: 100)
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
        case 1: return TokenScopeTheme.chartGreen.opacity(0.3)
        case 2: return TokenScopeTheme.chartGreen.opacity(0.5)
        case 3: return TokenScopeTheme.chartGreen.opacity(0.75)
        case 4: return TokenScopeTheme.chartGreen
        default: return TokenScopeTheme.separator
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
}

// MARK: - Subcomponents

private struct PeriodButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? TokenScopeTheme.segOnText : TokenScopeTheme.segOffText)
                .frame(width: 50, height: 24)
                .background(isSelected ? TokenScopeTheme.segOnBg : Color.clear)
                .cornerRadius(6)
                .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.clear, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct TrendCard: View {
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
                        .foregroundColor(TokenScopeTheme.textSecondary)
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(TokenScopeTheme.textMain)
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TokenScopeTheme.textSecondary)
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
        .padding(16)
        .background(TokenScopeTheme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TokenScopeTheme.separator, lineWidth: 1))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TokenScopeTheme.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(TokenScopeTheme.textMain)
            }
            Spacer()
        }
    }
}

private struct SparklineView: View {
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
