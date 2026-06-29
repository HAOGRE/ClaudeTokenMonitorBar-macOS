import Foundation
import SwiftUI

// MARK: - Agent 标识

/// 支持的 AI coding agent 枚举
enum AgentKind: String, CaseIterable, Sendable {
    case claude = "claude"
    case codex  = "codex"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex:  return "Codex"
        case .gemini: return "Gemini CLI"
        }
    }

    /// 用于状态栏圆点 / 进度条的强调色
    var color: Color {
        switch self {
        case .claude: return Color(red: 0.90, green: 0.57, blue: 0.29)  // 橙棕色（Claude 品牌色）
        case .codex:  return Color(red: 0.12, green: 0.80, blue: 0.42)  // 绿色（OpenAI 品牌色）
        case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96)  // 蓝色（Google 品牌色）
        }
    }
}

// MARK: - 通用聚合数据结构

/// 单个 Agent 的全量聚合数据（所有 AgentLogReader 实现统一返回此结构）
struct AllAgentData: Sendable {
    let agentKind: AgentKind

    // 全部（受 since 过滤）
    let totalCost: Double
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheReadTokens: Int

    // 今日
    let todayCost: Double
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let todayCacheReadTokens: Int

    // 明细
    let recentEntries: [UsageEntry]
    let projectCosts: [String: Double]

    // 每日历史（用于图表）
    let dailyHistory: [(day: Date, cost: Double, tokens: Int)]

    // 限额状态（Claude 用 V4StateProtocol，Codex 用 rate_limits 转换）
    let rateLimitState: AgentRateLimitState?

    static func empty(for kind: AgentKind) -> AllAgentData {
        AllAgentData(
            agentKind: kind,
            totalCost: 0, totalInputTokens: 0, totalOutputTokens: 0, totalCacheReadTokens: 0,
            todayCost: 0, todayInputTokens: 0, todayOutputTokens: 0, todayCacheReadTokens: 0,
            recentEntries: [], projectCosts: [:], dailyHistory: [],
            rateLimitState: nil
        )
    }
}

// MARK: - 限额状态（跨 Agent 统一表示）

/// 通用限额状态——将 Claude v4 的 five_hour window 和 Codex 的 primary window 统一表示
struct AgentRateLimitState: Sendable {
    /// 窗口长度（分钟）
    let windowMinutes: Int
    /// 已用百分比 (0–100)
    let usedPercent: Double
    /// 重置时间（描述字符串，如 "in 2h 15m"）
    let resetsDescription: String?

    /// 从 Claude v4 state 转换
    static func from(v4State: V4StateProtocol) -> AgentRateLimitState? {
        guard let fiveHour = v4State.limits?.five_hour else { return nil }
        return AgentRateLimitState(
            windowMinutes: 300,
            usedPercent: fiveHour.used_percentage ?? 0,
            resetsDescription: fiveHour.resets_at
        )
    }
}

// MARK: - AgentLogReader 协议

/// 所有 AI agent 数据读取器遵循此协议
/// 实现要求：
///   - 线程安全（loadAllData 在 background Task.detached 里调用）
///   - isInstalled 检查对应目录是否存在，用于判断是否展示该 Agent
protocol AgentLogReader: Sendable {
    var kind: AgentKind { get }

    /// 是否已安装（对应数据目录是否存在）
    var isInstalled: Bool { get }

    /// 加载全量数据（在后台线程调用）
    func loadAllData(since: Date?, daysBack: Int) -> AllAgentData
}

// MARK: - 工具方法

extension AgentLogReader {
    /// 获取用户真实 Home 目录（绕过沙盒限制）
    func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir {
            return String(cString: homeDir)
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            return home
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
}
