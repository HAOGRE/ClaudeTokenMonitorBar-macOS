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

    var panelBg: Color { dynamic(light: "#fcfdfc", dark: "#1c1e22") }
    var softCardBg: Color { dynamic(light: "#eef1ef", dark: "#2a2d31") }
    var panelBorder: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.06), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.12)) }

    var primaryGreen: Color { dynamic(light: "#4b9665", dark: "#70b687") }
    var chartGreen: Color { dynamic(light: "#3f8758", dark: "#63a978") }
    var lightGreen: Color { dynamic(light: "#a7dbc0", dark: "#8ed8ab") }
    var warning: Color { dynamic(light: "#b07a28", dark: "#e0a34e") }
    var danger: Color { dynamic(light: "#bf5a4a", dark: "#e57a68") }

    var textMain: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.94), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.88)) }
    var textSecondary: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.48), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.55)) }
    var textTertiary: Color { dynamic(light: NSColor(red: 34/255, green: 38/255, blue: 36/255, alpha: 0.38), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.40)) }
    var separator: Color { dynamic(light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.055), dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.09)) }
    var track: Color { dynamic(light: "#ecf0ed", dark: "#33363b") }

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
    static let panelWidth: CGFloat = 360
    static let panelHeight: CGFloat = 760
    static let panelRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let sectionTitleSize: CGFloat = 10.5
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
        case 0: return l10n.str(.trendToday)
        case 1: return l10n.str(.trendThisWeek)
        default: return l10n.str(.trendThisMonth)
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
                // 模块排序按关注度：①Hero ②限额 ③用量图表 为固定模块；其余可在设置中隐藏
                VStack(spacing: DashboardLayout.sectionSpacing) {
                    heroSection

                    if let limits = viewModel.monitoringData.v4State?.limits,
                       let fiveHour = limits.five_hour {
                        v4RateLimitsSection(
                            fiveHour: fiveHour,
                            sevenDay: limits.seven_day,
                            source: viewModel.monitoringData.limitSource
                        )
                    }

                    splitBarSection
                    barChartSection

                    if settings.showModelsSection {
                        sectionDivider
                        modelsSection
                    }

                    if settings.showTrendSection {
                        sectionDivider
                        trendCardsSection
                    }

                    if settings.showMcpSkillSection {
                        sectionDivider
                        mcpSkillCardsSection
                    }

                    if settings.showHeatmapSection {
                        sectionDivider
                        heatmapSection
                    }
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
            HStack(spacing: 7) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("CTMB")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textMain)
                if viewModel.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.warning)
                        .help(l10n.str(.noDataError))
                }
            }

            Spacer()

            HStack(spacing: 2) {
                PeriodButton(title: l10n.str(.periodDay), isSelected: selectedPeriod == 0) { selectedPeriod = 0 }
                PeriodButton(title: l10n.str(.periodWeek), isSelected: selectedPeriod == 1) { selectedPeriod = 1 }
                PeriodButton(title: l10n.str(.periodMonth), isSelected: selectedPeriod == 2) { selectedPeriod = 2 }
            }
            .padding(2)
            .background(theme.segBg)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.segBorder, lineWidth: 1)
            )

            headerIconButton(
                systemName: "gearshape",
                help: l10n.str(.settingsHelp),
                action: { showingSettings = true }
            )
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

    private var sectionDivider: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(height: 1)
    }
    
    private var heroSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.str(.totalTokensTitle))
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
                    Text(l10n.str(.estCost))
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
            // 三段 Input / Cache / Output，与 TOTAL TOKENS（含 cache）口径一致
            let metrics = currentReport.metrics
            let cacheColor = theme.palette[3]
            let total = max(1, metrics.inputTokens + metrics.cacheTokens + metrics.outputTokens)
            let inRatio = Double(metrics.inputTokens) / Double(total)
            let cacheRatio = Double(metrics.cacheTokens) / Double(total)
            let outRatio = Double(metrics.outputTokens) / Double(total)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.track)
                    if metrics.totalTokens > 0 {
                        HStack(spacing: 0) {
                            theme.chartGreen.frame(width: geo.size.width * CGFloat(inRatio))
                            cacheColor.frame(width: geo.size.width * CGFloat(cacheRatio))
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
                    Text("\(l10n.str(.inputLabel)) \(formatLargeNumberStr(metrics.inputTokens))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(cacheColor).frame(width: 7, height: 7)
                    Text("\(l10n.str(.cacheLabel)) \(formatLargeNumberStr(metrics.cacheTokens))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(theme.lightGreen).frame(width: 7, height: 7)
                    Text("\(l10n.str(.outputLabel)) \(formatLargeNumberStr(metrics.outputTokens))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
    }
    
    private var barChartSection: some View {
        // X 轴分类值必须用唯一的 full 字段：label 大量为空字符串，
        // Swift Charts 会把相同分类值堆到同一根柱（Day/Month 视图曾因此柱子合并）
        let sparseMarks = currentReport.series.filter { !$0.label.isEmpty }
        let labelByFull = Dictionary(sparseMarks.map { ($0.full, $0.label) }, uniquingKeysWith: { first, _ in first })

        return VStack {
            Chart(currentReport.series) { item in
                BarMark(x: .value("Time", item.full), y: .value("Input", item.input))
                    .foregroundStyle(theme.chartGreen)
                BarMark(x: .value("Time", item.full), y: .value("Output", item.output))
                    .foregroundStyle(theme.lightGreen)
            }
            .chartLegend(.hidden)
            .chartXAxis {
                // 只在有 label 的位置显示稀疏刻度（如 Day 视图每 4 小时一个）
                AxisMarks(values: sparseMarks.map(\.full)) { value in
                    AxisValueLabel {
                        if let full = value.as(String.self), let label = labelByFull[full] {
                            Text(label)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
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
    
    /// 双环形图：左 Tokens、右 Cost，图例在图形下方
    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if currentReport.models.isEmpty {
                Text(l10n.str(.tokensByModel))
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                compactEmptyState(l10n.str(.emptyUsage))
            } else {
                let models = Array(currentReport.models.prefix(4))
                HStack(alignment: .top, spacing: 12) {
                    donutColumn(
                        title: l10n.str(.tokensByModel),
                        centerText: formatLargeNumberStr(currentReport.metrics.totalTokens),
                        models: models,
                        value: { Double($0.tokens) },
                        display: { formatLargeNumberStr($0.tokens) }
                    )
                    donutColumn(
                        title: l10n.str(.costByModel),
                        centerText: MonitoringViewModel.formatCost(currentReport.metrics.cost),
                        models: models,
                        value: { $0.cost },
                        display: { MonitoringViewModel.formatCost($0.cost) }
                    )
                }
            }
        }
    }

    private func donutColumn(
        title: String,
        centerText: String,
        models: [ModelStat],
        value: @escaping (ModelStat) -> Double,
        display: @escaping (ModelStat) -> String
    ) -> some View {
        VStack(spacing: 9) {
            Text(title)
                .sectionTitleFont()
                .foregroundColor(theme.textSecondary)

            ZStack {
                Chart {
                    ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                        SectorMark(
                            angle: .value("Value", value(model)),
                            innerRadius: .ratio(0.7),
                            angularInset: 1.5
                        )
                        .foregroundStyle(theme.palette[index % theme.palette.count])
                    }
                }
                Text(centerText)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textMain)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: 104, height: 104)

            // 图例在图形下方：色块 + 短模型名 + 数值
            VStack(spacing: 4) {
                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(theme.palette[index % theme.palette.count])
                            .frame(width: 7, height: 7)
                        Text(legendModelName(model.name))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textMain)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(display(model))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var trendCardsSection: some View {
        HStack(spacing: 10) {
            TrendCard(
                title: l10n.str(.requestsTitle),
                value: formatWholeNumber(currentReport.metrics.requests),
                subtitle: String(format: l10n.str(.sessionsFormat), formatWholeNumber(currentReport.metrics.sessions)),
                points: currentReport.reqTrend,
                color: theme.primaryGreen,
                valueColor: nil
            )
            TrendCard(
                title: l10n.str(.costTrendTitle),
                value: MonitoringViewModel.formatCost(currentReport.metrics.cost),
                subtitle: trendSubtitle,
                points: currentReport.costTrend,
                color: theme.primaryGreen,
                valueColor: theme.primaryGreen
            )
        }
    }

    private func v4RateLimitsSection(fiveHour: V4LimitDetail, sevenDay: V4LimitDetail?, source: LimitSource) -> some View {
        let isEstimated = source == .localEstimate
        let (icon, title): (String, String) = {
            switch source {
            case .officialApi:   return ("checkmark.seal.fill", l10n.str(.v4SectionTitleOfficial))
            case .daemonFile:    return ("shield.checkerboard", l10n.str(.v4SectionTitle))
            default:             return ("exclamationmark.triangle", l10n.str(.v4SectionTitleEstimated))
            }
        }()

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(source == .officialApi ? theme.primaryGreen : (isEstimated ? theme.warning : theme.textSecondary))
                Text(title)
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }

            limitRow(title: l10n.str(.v4FiveHourWindow), detail: fiveHour)
            if let sevenDay {
                limitRow(title: l10n.str(.v4SevenDayWindow), detail: sevenDay)
            }
            burnRateFooter(fiveHour: fiveHour)

            if isEstimated {
                Text(l10n.str(.v4EstimatedDisclaimer))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(theme.softCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func limitRow(title: String, detail: V4LimitDetail) -> some View {
        let used = detail.tokens_used ?? 0
        let limit = max(detail.token_limit ?? 1, 1)
        let percentage = detail.used_percentage ?? (Double(used) / Double(limit) * 100)

        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(percentage > 90 ? theme.danger : (percentage > 75 ? theme.warning : theme.textMain))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.separator)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(percentage > 90 ? theme.danger : (percentage > 75 ? theme.warning : theme.primaryGreen))
                        .frame(width: max(0, geo.size.width * CGFloat(min(percentage, 100) / 100)), height: 6)
                }
            }
            .frame(height: 6)

            if let resetsAt = detail.resets_at {
                HStack {
                    Spacer()
                    Text("\(l10n.str(.v4ResetsAt)) \(displayResetsAt(resetsAt))")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
    }

    private func burnRateFooter(fiveHour: V4LimitDetail) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "flame")
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)
            Text("\(MonitoringViewModel.formatTokens(Int(viewModel.burnRatePerMin))) tok/min")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
            Spacer()
            if let prediction = predictionText(fiveHour: fiveHour) {
                Text(prediction)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(prediction == l10n.str(.v4NoHitBeforeReset) ? theme.textSecondary : theme.warning)
            }
        }
    }

    private func predictionText(fiveHour: V4LimitDetail) -> String? {
        let rate = viewModel.burnRatePerMin
        guard rate > 0, let limit = fiveHour.token_limit, let used = fiveHour.tokens_used else { return nil }
        let remaining = limit - used
        guard remaining > 0 else { return l10n.str(.v4LimitReached) }
        let predicted = Date().addingTimeInterval(Double(remaining) / rate * 60)
        if let reset = parseResetsAt(fiveHour.resets_at), predicted > reset {
            return l10n.str(.v4NoHitBeforeReset)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return String(format: l10n.str(.v4PredictHit), formatter.string(from: predicted))
    }

    /// resets_at 友好化显示：ISO 时间戳转本地时间（今天只显示时刻，跨天带日期）；
    /// 无法解析（如守护进程的 "in 2h 15m"）则原样返回
    private func displayResetsAt(_ raw: String) -> String {
        guard raw.contains("T"), let date = parseResetsAt(raw) else { return raw }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }

    /// ISO 时间戳解析（含 OAuth API 的 6 位微秒格式，ISO8601DateFormatter 不支持）
    private static let microsecondISOFormatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    // best-effort parse：ISO 时间戳（OAuth API / state 文件）或人类可读的 "in 1h 23m"（守护进程）
    private func parseResetsAt(_ value: String?) -> Date? {
        guard let value else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        for formatter in Self.microsecondISOFormatters {
            if let date = formatter.date(from: value) { return date }
        }
        var seconds: TimeInterval = 0
        if let match = value.firstMatch(of: /(\d+)\s*d/), let n = Double(match.1) { seconds += n * 86400 }
        if let match = value.firstMatch(of: /(\d+)\s*h/), let n = Double(match.1) { seconds += n * 3600 }
        if let match = value.firstMatch(of: /(\d+)\s*m/), let n = Double(match.1) { seconds += n * 60 }
        return seconds > 0 ? Date().addingTimeInterval(seconds) : nil
    }
    
    /// MCP / Skill 调用：左右双卡（与 Requests/Cost Trend 同风格）
    private var mcpSkillCardsSection: some View {
        HStack(spacing: 10) {
            CompactStatCard(
                title: l10n.str(.mcpCallsTitle),
                value: formatWholeNumber(currentReport.metrics.mcpCalls),
                subtitle: String(format: l10n.str(.serversFormat), "\(currentReport.metrics.servers)"),
                items: Array(currentReport.mcp.prefix(3)),
                emptyText: l10n.str(.emptyMcp)
            )
            CompactStatCard(
                title: l10n.str(.skillCallsTitle),
                value: formatWholeNumber(currentReport.metrics.skillCalls),
                subtitle: String(format: l10n.str(.skillsCountFormat), "\(currentReport.metrics.skills)"),
                items: Array(currentReport.skills.prefix(3)),
                emptyText: l10n.str(.emptySkill)
            )
        }
    }
    
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(l10n.str(.dailyActivity))
                .sectionTitleFont()
                .foregroundColor(theme.textSecondary)

            let heatmap = viewModel.monitoringData.dashboard.heatmap
            if heatmap.isEmpty {
                compactEmptyState(l10n.str(.emptyDaily))
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
                        Text(l10n.str(.legendLess))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.trailing, 2)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(colorForLevel(level))
                                .frame(width: DashboardLayout.heatmapCell, height: DashboardLayout.heatmapCell)
                        }
                        Text(l10n.str(.legendMore))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .padding(.leading, 2)
                    }
                    .frame(width: gridWidth, alignment: .trailing)
                }
            }
        }
    }
    
    // MARK: - Helpers

    private func compactEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textTertiary)
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

    /// 环形图图例用的极短模型名（去掉 "Claude " 前缀，节省横向空间）
    private func legendModelName(_ full: String) -> String {
        let short = shortModelName(full)
        if short.hasPrefix("Claude ") { return String(short.dropFirst(7)) }
        return short
    }
    
    private func formatLargeNumber(_ count: Int) -> (value: String, suffix: String) {
        if count == 0 {
            return ("0", "")
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .frame(minWidth: 42, minHeight: 22)
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
    let valueColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .sectionTitleFont()
                        .foregroundColor(theme.textSecondary)
                    Text(value)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(valueColor ?? theme.textMain)
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

/// MCP/Skill 紧凑统计卡：左侧标题+大数字+副标题，右侧 top-3 迷你列表
private struct CompactStatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: Theme { Theme(isDark: colorScheme == .dark) }
    let title: String
    let value: String
    let subtitle: String
    let items: [NamedCount]
    let emptyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .sectionTitleFont()
                    .foregroundColor(theme.textSecondary)
                Text(value)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textMain)
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if items.isEmpty {
                Text(emptyText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(items) { item in
                        HStack(spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(item.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textMain)
                                .monospacedDigit()
                        }
                        .help(item.name)
                    }
                }
                .frame(maxWidth: 80, alignment: .trailing)
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
