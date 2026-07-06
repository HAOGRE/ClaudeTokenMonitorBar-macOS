import Foundation
import Security
import os.log

/// 官方 OAuth usage API 读取器 —— Claude Code `/usage` 命令同源数据
///
/// GET https://api.anthropic.com/api/oauth/usage
/// - 凭证：macOS Keychain "Claude Code-credentials"（Claude Code 自己写入），
///   fallback ~/.claude/.credentials.json（Linux 格式）、env CLAUDE_CODE_OAUTH_TOKEN
/// - Token 约 60 分钟过期，Claude Code 运行时自动续期；本类不做刷新，失败即返回 nil
///   由上层回落到守护进程 state 文件 / 本地估算
/// - User-Agent 必须伪装为 claude-code/<version>，否则命中严格限流桶（持续 429）
/// - 官方安全轮询间隔 ≥180s，内部缓存保证外层高频刷新不会打爆 API
/// - 沙盒版（AppStore）读不到其他 App 的 Keychain，会自然走 fallback 链
actor OAuthUsageReader {
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "oauth_usage")

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let keychainService = "Claude Code-credentials"
    private static let userAgent = "claude-code/2.0.0"

    /// 成功后的最小重新拉取间隔（官方安全值）
    private let refreshInterval: TimeInterval = 180
    /// 失败后的重试间隔（避免每 5 秒重复失败请求/Keychain 弹窗）
    private let failureRetryInterval: TimeInterval = 180
    /// 拉取失败时，旧缓存的最长可用时间（超过则视为过期，返回 nil 回落）
    private let staleTolerance: TimeInterval = 15 * 60

    private var cachedState: V4StateProtocol?
    private var lastSuccess: Date?
    private var lastAttempt: Date?

    /// 读取官方限额状态；不可用时返回 nil（上层回落）
    func readState() async -> V4StateProtocol? {
        let now = Date()

        // 缓存新鲜，直接返回
        if let cached = cachedState, let success = lastSuccess,
           now.timeIntervalSince(success) < refreshInterval {
            return cached
        }
        // 距上次尝试太近（含失败），不重复请求；有可容忍的旧缓存就先用
        if let attempt = lastAttempt, now.timeIntervalSince(attempt) < failureRetryInterval {
            return usableStaleCache(now: now)
        }

        lastAttempt = now
        guard let token = readAccessToken() else {
            return usableStaleCache(now: now)
        }

        do {
            let state = try await fetchUsage(token: token)
            cachedState = state
            lastSuccess = now
            return state
        } catch {
            logger.warning("OAuth usage 拉取失败: \(error.localizedDescription)")
            return usableStaleCache(now: now)
        }
    }

    private func usableStaleCache(now: Date) -> V4StateProtocol? {
        if let cached = cachedState, let success = lastSuccess,
           now.timeIntervalSince(success) < staleTolerance {
            return cached
        }
        return nil
    }

    // MARK: - 凭证读取

    private func readAccessToken() -> String? {
        // 1) macOS Keychain（Claude Code 官方存储位置；首次读取系统会弹授权框）
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data,
           let token = parseCredentials(data) {
            return token
        }
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.info("Keychain 读取失败 (status=\(status))，尝试 fallback")
        }

        // 2) ~/.claude/.credentials.json（Linux/Windows 格式，同结构）
        let credPath = realHomeDirectory() + "/.claude/.credentials.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: credPath)),
           let token = parseCredentials(data) {
            return token
        }

        // 3) 环境变量（CI / setup-token 场景）
        if let token = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"],
           !token.isEmpty {
            return token
        }

        return nil
    }

    /// 解析凭证 JSON：{ "claudeAiOauth": { "accessToken": "...", "expiresAt": <epoch_ms> } }
    /// 已过期的 token 返回 nil（省一次必然 401 的请求）
    private func parseCredentials(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else {
            return nil
        }
        if let expiresAt = oauth["expiresAt"] as? Double,
           expiresAt / 1000 < Date().timeIntervalSince1970 {
            logger.info("OAuth token 已过期（Claude Code 未运行时不会续期）")
            return nil
        }
        return token
    }

    private func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir {
            return String(cString: homeDir)
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    // MARK: - API 调用与映射

    private struct UsageResponse: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        /// 新版 API 的权威限额数组（kind: session / weekly_all）；
        /// 顶层 five_hour/seven_day 为旧版兼容字段，会间歇性返回空值
        struct Limit: Decodable {
            let kind: String?
            let percent: Double?
            let resets_at: String?
        }
        let five_hour: Window?
        let seven_day: Window?
        let limits: [Limit]?
    }

    private enum FetchError: Error, LocalizedError {
        case badStatus(Int)
        var errorDescription: String? {
            if case .badStatus(let code) = self { return "HTTP \(code)" }
            return nil
        }
    }

    private func fetchUsage(token: String) async throws -> V4StateProtocol {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)

        // 映射为与守护进程 state 文件一致的结构，UI 统一处理
        // OAuth API 只有百分比 + 重置时间，没有 token 数量
        // 优先取 limits[] 数组（新版权威数据），旧版顶层字段兜底
        func detail(kind: String, legacy: UsageResponse.Window?) -> V4LimitDetail? {
            if let l = usage.limits?.first(where: { $0.kind == kind }),
               l.percent != nil || l.resets_at != nil {
                return V4LimitDetail(
                    used_percentage: l.percent,
                    tokens_used: nil,
                    token_limit: nil,
                    resets_at: l.resets_at
                )
            }
            guard let legacy else { return nil }
            return V4LimitDetail(
                used_percentage: legacy.utilization,
                tokens_used: nil,
                token_limit: nil,
                resets_at: legacy.resets_at
            )
        }

        return V4StateProtocol(
            schema_version: "oauth-api",
            generated_at: ISO8601DateFormatter().string(from: Date()),
            confidence: "official",
            stale: false,
            plan: nil,
            limits: V4Limits(
                five_hour: detail(kind: "session", legacy: usage.five_hour),
                seven_day: detail(kind: "weekly_all", legacy: usage.seven_day)
            ),
            local: nil,
            local_history: nil
        )
    }
}
