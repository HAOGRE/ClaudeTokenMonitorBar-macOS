import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh"
    case english = "en"
}

enum LocalizedKey {
    // SettingsView
    case settingsTitle, sectionSystem, sectionDisplay
    case launchAtLoginTitle, launchAtLoginSubtitle
    case showDockIconTitle, showDockIconSubtitle
    case refreshIntervalTitle, refreshIntervalSubtitle
    case topProjectsTitle, topProjectsSubtitle
    case recentRecordsTitle, recentRecordsSubtitle
    // StatusBarView - 头部与周期切换
    case periodDay, periodWeek, periodMonth
    case copySnapshotHelp, settingsHelp
    // StatusBarView - Hero 区
    case totalTokensTitle, estCost
    case inputLabel, outputLabel, cacheLabel
    // StatusBarView - 分区标题
    case tokensByModel, costByModel
    case requestsTitle, costTrendTitle
    case mcpCallsTitle, skillCallsTitle
    case dailyActivity
    // StatusBarView - 格式化文案（String(format:) 占位）
    case sessionsFormat        // "%@ sessions"
    case mcpHeaderFormat       // "%@ · %@ servers"
    case skillHeaderFormat     // "%@ · %@ skills"
    case moreFormat            // "+%d more"
    // StatusBarView - 空状态
    case emptyUsage, emptyModelCost, emptyMcp, emptySkill, emptyDaily
    // StatusBarView - 趋势副标题
    case trendToday, trendThisWeek, trendThisMonth
    // StatusBarView - 热力图图例
    case legendLess, legendMore
    // 底栏
    case resetButton, quitButton
    // ViewModel
    case noDataError
    // v4 Rate Limits
    case v4SectionTitle, v4SectionTitleEstimated, v4FiveHourWindow, v4ResetsAt
    case v4SevenDayWindow, v4PredictHit, v4NoHitBeforeReset, v4LimitReached, v4EstimatedDisclaimer
}

@Observable
final class L10n {
    static let shared = L10n()
    private init() {}

    var language: AppLanguage {
        let systemLang = Locale.current.language.languageCode?.identifier ?? "zh"
        return systemLang.hasPrefix("zh") ? .chinese : .english
    }

    func str(_ key: LocalizedKey) -> String {
        strings[language]?[key] ?? strings[.chinese]?[key] ?? "\(key)"
    }

    func refreshSec(_ sec: Int) -> String {
        language == .chinese ? "\(sec) 秒" : "\(sec) sec"
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
            .topProjectsTitle:       "MCP 调用",
            .topProjectsSubtitle:    "显示已安装 MCP 服务的调用统计",
            .recentRecordsTitle:     "Skill 调用",
            .recentRecordsSubtitle:  "显示已安装 Skill 的调用统计",
            .periodDay:              "日",
            .periodWeek:             "周",
            .periodMonth:            "月",
            .copySnapshotHelp:       "复制面板截图",
            .settingsHelp:           "设置",
            .totalTokensTitle:       "总 TOKENS",
            .estCost:                "预估成本",
            .inputLabel:             "输入",
            .outputLabel:            "输出",
            .cacheLabel:             "缓存",
            .tokensByModel:          "按模型 TOKENS",
            .costByModel:            "按模型成本",
            .requestsTitle:          "请求数",
            .costTrendTitle:         "成本趋势",
            .mcpCallsTitle:          "MCP 调用",
            .skillCallsTitle:        "SKILL 调用",
            .dailyActivity:          "每日活跃",
            .sessionsFormat:         "%@ 个会话",
            .mcpHeaderFormat:        "%@ · %@ 个服务",
            .skillHeaderFormat:      "%@ · %@ 个技能",
            .moreFormat:             "还有 %d 个",
            .emptyUsage:             "本期无用量",
            .emptyModelCost:         "本期无模型成本",
            .emptyMcp:               "本期无 MCP 调用",
            .emptySkill:             "本期无 Skill 调用",
            .emptyDaily:             "暂无每日活跃数据",
            .trendToday:             "今天",
            .trendThisWeek:          "本周",
            .trendThisMonth:         "本月",
            .legendLess:             "少",
            .legendMore:             "多",
            .resetButton:            "重置",
            .quitButton:             "退出",
            .noDataError:            "未找到数据，请检查本地用量数据目录访问权限",
            .v4SectionTitle:         "官方速率限制 (v4)",
            .v4SectionTitleEstimated:"速率限制 (本地估算)",
            .v4FiveHourWindow:       "5 小时窗口",
            .v4ResetsAt:             "重置于",
            .v4SevenDayWindow:       "7 天窗口",
            .v4PredictHit:           "预计 %@ 触顶",
            .v4NoHitBeforeReset:     "重置前不会触顶",
            .v4LimitReached:         "已达上限",
            .v4EstimatedDisclaimer:  "基于本地 session 数据估算。安装 claude-code-usage-monitor 获取官方限额数据。",
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
            .topProjectsTitle:       "MCP Calls",
            .topProjectsSubtitle:    "Show call stats for installed MCP servers",
            .recentRecordsTitle:     "Skill Calls",
            .recentRecordsSubtitle:  "Show call stats for installed Skills",
            .periodDay:              "Day",
            .periodWeek:             "Week",
            .periodMonth:            "Month",
            .copySnapshotHelp:       "Copy panel snapshot",
            .settingsHelp:           "Settings",
            .totalTokensTitle:       "TOTAL TOKENS",
            .estCost:                "Est. cost",
            .inputLabel:             "Input",
            .outputLabel:            "Output",
            .cacheLabel:             "Cache",
            .tokensByModel:          "TOKENS BY MODEL",
            .costByModel:            "COST BY MODEL",
            .requestsTitle:          "REQUESTS",
            .costTrendTitle:         "COST TREND",
            .mcpCallsTitle:          "MCP CALLS",
            .skillCallsTitle:        "SKILL CALLS",
            .dailyActivity:          "DAILY ACTIVITY",
            .sessionsFormat:         "%@ sessions",
            .mcpHeaderFormat:        "%@ · %@ servers",
            .skillHeaderFormat:      "%@ · %@ skills",
            .moreFormat:             "+%d more",
            .emptyUsage:             "No usage in this period",
            .emptyModelCost:         "No model costs in this period",
            .emptyMcp:               "No MCP calls in this period",
            .emptySkill:             "No skill calls in this period",
            .emptyDaily:             "No daily activity",
            .trendToday:             "today",
            .trendThisWeek:          "this week",
            .trendThisMonth:         "this month",
            .legendLess:             "Less",
            .legendMore:             "More",
            .resetButton:            "Reset",
            .quitButton:             "Quit",
            .noDataError:            "No data found. Please check local usage data folder access",
            .v4SectionTitle:         "Official Rate Limits (v4)",
            .v4SectionTitleEstimated:"Rate Limits (Estimated)",
            .v4FiveHourWindow:       "5-Hour Window",
            .v4ResetsAt:             "Resets at",
            .v4SevenDayWindow:       "7-Day Window",
            .v4PredictHit:           "Est. limit at %@",
            .v4NoHitBeforeReset:     "Won't hit before reset",
            .v4LimitReached:         "Limit reached",
            .v4EstimatedDisclaimer:  "Based on local session data. Install claude-code-usage-monitor for official limits.",
        ],
    ]
}
