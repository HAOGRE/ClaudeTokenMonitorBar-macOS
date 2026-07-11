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
    case periodModeTitle, periodModeSubtitle
    case periodModeRolling, periodModeCalendar
    case showModelsTitle, showModelsSubtitle
    case showTrendTitle, showTrendSubtitle
    case showMcpSkillTitle, showMcpSkillSubtitle
    case showHeatmapTitle, showHeatmapSubtitle
    // StatusBarView - 头部与周期切换
    case periodDay, periodWeek, periodMonth
    case copySnapshotHelp, settingsHelp
    // StatusBarView - Hero 区
    case totalTokensTitle, estCost
    case inputLabel, outputLabel, cacheLabel
    case cacheSavedLabel
    // StatusBarView - 分区标题
    case tokensByModel, costByModel
    case modelColumn, tokensColumn, costColumn
    case requestsTitle, costTrendTitle
    case mcpCallsTitle, skillCallsTitle
    case dailyActivity
    // Codex section
    case codexTitle, codexTokensUnit, codexInputLabel, codexCachedInputLabel, codexOutputLabel, codexReasoningLabel
    case codexCurrentSession, codexLastUpdated, codexRateLabel
    case codexPrimaryWindow, codexSecondaryWindow, codexGrantAccess, codexAccessRequired, codexAccessGranted
    case codexUnavailable, codexNoActivity
    case codexScannedFilesFormat, codexCurrentSessionFormat
    case sourceSwitchHelp, tokenTrendTitle
    // StatusBarView - 格式化文案（String(format:) 占位）
    case sessionsFormat        // "%@ sessions"
    case serversFormat         // "%@ servers"
    case skillsCountFormat     // "%@ skills"
    // StatusBarView - 空状态
    case emptyUsage, emptyMcp, emptySkill, emptyDaily
    // StatusBarView - 趋势副标题
    case trendToday, trendThisWeek, trendThisMonth
    case trendLast7Days, trendLast30Days
    // StatusBarView - 热力图图例
    case legendLess, legendMore
    // ViewModel
    case noDataError
    // v4 Rate Limits
    case v4SectionTitleOfficial, v4SectionTitle, v4SectionTitleEstimated
    case v4FiveHourWindow, v4ResetsAt
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
            .periodModeTitle:        "统计口径",
            .periodModeSubtitle:     "周/月的统计范围",
            .periodModeRolling:      "近 7/30 天",
            .periodModeCalendar:     "自然周/月",
            .showModelsTitle:        "模型统计",
            .showModelsSubtitle:     "按模型的 Tokens 与成本环形图",
            .showTrendTitle:         "趋势卡片",
            .showTrendSubtitle:      "请求数与成本趋势",
            .showMcpSkillTitle:      "MCP / Skill 调用",
            .showMcpSkillSubtitle:   "MCP 与 Skill 调用统计卡片",
            .showHeatmapTitle:       "每日活跃热力图",
            .showHeatmapSubtitle:    "近 6 个月的活跃热力图",
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
            .cacheSavedLabel:        "缓存节省",
            .tokensByModel:          "按模型 TOKENS",
            .costByModel:            "按模型成本",
            .modelColumn:            "模型",
            .tokensColumn:           "TOKENS",
            .costColumn:             "成本",
            .requestsTitle:          "请求数",
            .costTrendTitle:         "成本趋势",
            .mcpCallsTitle:          "MCP 调用",
            .skillCallsTitle:        "SKILL 调用",
            .dailyActivity:          "每日活跃",
            .codexTitle:             "CODEX TOKEN 用量",
            .codexTokensUnit:        "tokens",
            .codexInputLabel:        "输入",
            .codexCachedInputLabel:  "缓存输入",
            .codexOutputLabel:       "输出",
            .codexReasoningLabel:    "推理输出",
            .codexCurrentSession:    "当前会话",
            .codexLastUpdated:       "最近活动",
            .codexRateLabel:         "实时速率",
            .codexPrimaryWindow:     "5 小时窗口",
            .codexSecondaryWindow:   "7 天窗口",
            .codexGrantAccess:       "授权 Codex 数据",
            .codexAccessRequired:    "需要访问 Codex 会话目录",
            .codexAccessGranted:     "Codex 数据目录已授权",
            .codexUnavailable:       "暂无法读取 Codex 配额",
            .codexNoActivity:        "暂无 Codex token 活动",
            .codexScannedFilesFormat:"扫描 %@ 个文件",
            .codexCurrentSessionFormat:"当前会话 %@ tokens",
            .sourceSwitchHelp:       "点击切换 Claude / Codex 视图",
            .tokenTrendTitle:        "TOKEN 趋势",
            .sessionsFormat:         "%@ 个会话",
            .serversFormat:          "%@ 个服务",
            .skillsCountFormat:      "%@ 个技能",
            .emptyUsage:             "本期无用量",
            .emptyMcp:               "无调用",
            .emptySkill:             "无调用",
            .emptyDaily:             "暂无每日活跃数据",
            .trendToday:             "今天",
            .trendThisWeek:          "本周",
            .trendThisMonth:         "本月",
            .trendLast7Days:         "近 7 天",
            .trendLast30Days:        "近 30 天",
            .legendLess:             "少",
            .legendMore:             "多",
            .noDataError:            "未找到数据，请检查本地用量数据目录访问权限",
            .v4SectionTitleOfficial: "官方限额 (实时)",
            .v4SectionTitle:         "速率限制 (monitor)",
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
            .periodModeTitle:        "Period Mode",
            .periodModeSubtitle:     "Range for Week/Month stats",
            .periodModeRolling:      "Last 7/30 days",
            .periodModeCalendar:     "Calendar week/month",
            .showModelsTitle:        "Model Breakdown",
            .showModelsSubtitle:     "Tokens & cost donuts by model",
            .showTrendTitle:         "Trend Cards",
            .showTrendSubtitle:      "Requests and cost trend",
            .showMcpSkillTitle:      "MCP / Skill Calls",
            .showMcpSkillSubtitle:   "MCP & Skill call stat cards",
            .showHeatmapTitle:       "Daily Activity Heatmap",
            .showHeatmapSubtitle:    "6-month activity heatmap",
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
            .cacheSavedLabel:        "Cache Saved",
            .tokensByModel:          "TOKENS BY MODEL",
            .costByModel:            "COST BY MODEL",
            .modelColumn:            "MODEL",
            .tokensColumn:           "TOKENS",
            .costColumn:             "COST",
            .requestsTitle:          "REQUESTS",
            .costTrendTitle:         "COST TREND",
            .mcpCallsTitle:          "MCP CALLS",
            .skillCallsTitle:        "SKILL CALLS",
            .dailyActivity:          "DAILY ACTIVITY",
            .codexTitle:             "CODEX TOKEN USAGE",
            .codexTokensUnit:        "tokens",
            .codexInputLabel:        "Input",
            .codexCachedInputLabel:  "Cached",
            .codexOutputLabel:       "Output",
            .codexReasoningLabel:    "Reasoning",
            .codexCurrentSession:    "Current session",
            .codexLastUpdated:       "Last activity",
            .codexRateLabel:         "Live rate",
            .codexPrimaryWindow:     "5-hour window",
            .codexSecondaryWindow:   "7-day window",
            .codexGrantAccess:       "Grant Codex access",
            .codexAccessRequired:    "Access to the Codex sessions folder is required",
            .codexAccessGranted:     "Codex data folder authorized",
            .codexUnavailable:       "Codex quota data unavailable",
            .codexNoActivity:        "No Codex token activity",
            .codexScannedFilesFormat:"Scanned %@ files",
            .codexCurrentSessionFormat:"Current session %@ tokens",
            .sourceSwitchHelp:       "Click to switch between Claude and Codex",
            .tokenTrendTitle:        "TOKEN TREND",
            .sessionsFormat:         "%@ sessions",
            .serversFormat:          "%@ servers",
            .skillsCountFormat:      "%@ skills",
            .emptyUsage:             "No usage in this period",
            .emptyMcp:               "No calls",
            .emptySkill:             "No calls",
            .emptyDaily:             "No daily activity",
            .trendToday:             "today",
            .trendThisWeek:          "this week",
            .trendThisMonth:         "this month",
            .trendLast7Days:         "last 7 days",
            .trendLast30Days:        "last 30 days",
            .legendLess:             "Less",
            .legendMore:             "More",
            .noDataError:            "No data found. Please check local usage data folder access permissions",
            .v4SectionTitleOfficial: "Official Limits (Live)",
            .v4SectionTitle:         "Rate Limits (monitor)",
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
