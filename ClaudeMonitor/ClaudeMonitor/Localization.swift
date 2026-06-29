import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh"
    case english = "en"

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

enum LocalizedKey {
    // SettingsView
    case settingsTitle, sectionSystem, sectionDisplay
    case launchAtLoginTitle, launchAtLoginSubtitle
    case showDockIconTitle, showDockIconSubtitle
    case refreshIntervalTitle, refreshIntervalSubtitle
    case topProjectsTitle, topProjectsSubtitle
    case recentRecordsTitle, recentRecordsSubtitle
    case trendTitle, trendSubtitle
    // StatusBarView
    case appTitle, pickerAll, pickerToday
    case todayCost, totalCost
    case inputTokens, outputTokens, cacheRead
    case projectSectionTitle, noProjectData
    case recentSectionTitle, noRecentData
    case chartSectionTitle, resetButton, quitButton
    case rateInputLabel, rateOutputLabel
    case noChartData, axisDate, axisCost
    // ViewModel
    case noDataError
    // v4 Rate Limits
    case v4SectionTitle, v4FiveHourWindow, v4ResetsAt
}

@Observable
final class L10n {
    static let shared = L10n()
    private init() {}

    var language: AppLanguage = .chinese

    func str(_ key: LocalizedKey) -> String {
        strings[language]?[key] ?? strings[.chinese]?[key] ?? "\(key)"
    }

    func refreshSec(_ sec: Int) -> String {
        language == .chinese ? "\(sec) 秒" : "\(sec) sec"
    }

    var axisDate: String { str(.axisDate) }
    var axisCost: String { str(.axisCost) }

    /// App 标题：GitHub 版固定用品牌名，App Store 版用本地化名称
    var appTitle: String {
        #if GITHUB_BUILD
        return "Claude Token Monitor"
        #else
        return str(.appTitle)
        #endif
    }

    private let strings: [AppLanguage: [LocalizedKey: String]] = [
        .chinese: [
            .settingsTitle:          "设置",
            .sectionSystem:          "系统",
            .sectionDisplay:         "显示项",
            .launchAtLoginTitle:     "开机启动",
            .launchAtLoginSubtitle:  "登录后自动启动 AI Token 监控",
            .showDockIconTitle:      "显示 Dock 图标",
            .showDockIconSubtitle:   "在 Dock 栏显示应用图标",
            .refreshIntervalTitle:   "刷新间隔",
            .refreshIntervalSubtitle:"数据自动刷新的时间间隔",
            .topProjectsTitle:       "项目成本 TOP 5",
            .topProjectsSubtitle:    "显示成本最高的 5 个项目",
            .recentRecordsTitle:     "最近记录",
            .recentRecordsSubtitle:  "显示最近 5 条使用记录",
            .trendTitle:             "30 天趋势",
            .trendSubtitle:          "显示近 30 天的成本趋势图",
            .appTitle:               "AI Token 实时监控",
            .pickerAll:              "全部",
            .pickerToday:            "今天",
            .todayCost:              "今日成本",
            .totalCost:              "总成本",
            .inputTokens:            "输入 Tokens",
            .outputTokens:           "输出 Tokens",
            .cacheRead:              "缓存读取",
            .projectSectionTitle:    "项目成本 TOP 5",
            .noProjectData:          "暂无项目数据",
            .recentSectionTitle:     "最近记录",
            .noRecentData:           "暂无记录",
            .chartSectionTitle:      "30天趋势",
            .resetButton:            "重置",
            .quitButton:             "退出",
            .rateInputLabel:         "输入",
            .rateOutputLabel:        "输出",
            .noChartData:            "暂无历史数据",
            .axisDate:               "日期",
            .axisCost:               "成本",
            .noDataError:            "未找到数据，请检查本地用量数据目录访问权限",
            .v4SectionTitle:         "官方速率限制 (v4)",
            .v4FiveHourWindow:       "5 小时窗口",
            .v4ResetsAt:             "重置于",
        ],
        .english: [
            .settingsTitle:          "Settings",
            .sectionSystem:          "System",
            .sectionDisplay:         "Display",
            .launchAtLoginTitle:     "Launch at Login",
            .launchAtLoginSubtitle:  "Auto-start AI Token Monitor on login",
            .showDockIconTitle:      "Show Dock Icon",
            .showDockIconSubtitle:   "Display app icon in the Dock",
            .refreshIntervalTitle:   "Refresh Interval",
            .refreshIntervalSubtitle:"Interval for automatic data refresh",
            .topProjectsTitle:       "Top 5 Projects by Cost",
            .topProjectsSubtitle:    "Show the 5 most expensive projects",
            .recentRecordsTitle:     "Recent Records",
            .recentRecordsSubtitle:  "Show the latest 5 usage records",
            .trendTitle:             "30-Day Trend",
            .trendSubtitle:          "Show cost trend chart for the past 30 days",
            .appTitle:               "AI Token Monitor",
            .pickerAll:              "All",
            .pickerToday:            "Today",
            .todayCost:              "Today's Cost",
            .totalCost:              "Total Cost",
            .inputTokens:            "Input Tokens",
            .outputTokens:           "Output Tokens",
            .cacheRead:              "Cache Read",
            .projectSectionTitle:    "Top 5 Projects",
            .noProjectData:          "No project data",
            .recentSectionTitle:     "Recent Records",
            .noRecentData:           "No records",
            .chartSectionTitle:      "30-Day Trend",
            .resetButton:            "Reset",
            .quitButton:             "Quit",
            .rateInputLabel:         "In",
            .rateOutputLabel:        "Out",
            .noChartData:            "No historical data",
            .axisDate:               "Date",
            .axisCost:               "Cost",
            .noDataError:            "No data found. Please check local usage data folder access",
            .v4SectionTitle:         "Official Rate Limits (v4)",
            .v4FiveHourWindow:       "5-Hour Window",
            .v4ResetsAt:             "Resets at",
        ],
    ]
}
