import Foundation

struct CodexTokenTotals: Equatable, Sendable {
    var inputTokens: Int = 0
    var cachedInputTokens: Int = 0
    var outputTokens: Int = 0
    var reasoningOutputTokens: Int = 0
    var totalTokens: Int = 0
    var requestCount: Int = 0

    static let zero = CodexTokenTotals()

    var hasUsage: Bool {
        totalTokens > 0 || inputTokens > 0 || outputTokens > 0 || reasoningOutputTokens > 0
    }

    mutating func add(_ other: CodexTokenTotals) {
        inputTokens += other.inputTokens
        cachedInputTokens += other.cachedInputTokens
        outputTokens += other.outputTokens
        reasoningOutputTokens += other.reasoningOutputTokens
        totalTokens += other.totalTokens
        requestCount += other.requestCount
    }
}

enum CodexUsagePeriod: Sendable {
    case today
    case last7Days
    case last30Days
}

struct CodexRateLimitWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date
}

struct CodexUsageSnapshot: Sendable {
    let today: CodexTokenTotals
    let last7Days: CodexTokenTotals
    let last30Days: CodexTokenTotals
    let currentSession: CodexTokenTotals?
    let models: [String: CodexTokenTotals]
    let primaryRateLimit: CodexRateLimitWindow?
    let secondaryRateLimit: CodexRateLimitWindow?
    let lastTokenAt: Date?
    let scannedFileCount: Int
    /// 事件按 UsageEntry 形态导出（时间升序），复用 Claude 侧 Dashboard 聚合管线
    let entries: [UsageEntry]

    func totals(for period: CodexUsagePeriod) -> CodexTokenTotals {
        switch period {
        case .today: return today
        case .last7Days: return last7Days
        case .last30Days: return last30Days
        }
    }

    var hasUsage: Bool { today.hasUsage || last7Days.hasUsage || last30Days.hasUsage }
}

struct CodexUsageReader: Sendable {
    private let homeDirectory: String?

    init(homeDirectory: String? = nil) {
        self.homeDirectory = homeDirectory
    }

    func loadSnapshot(now: Date = Date()) -> CodexUsageSnapshot? {
        let root = resolvedHomeDirectory()
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root) else { return nil }

        let files = jsonlFiles(root: root, fileManager: fileManager)
        var events: [UsageEvent] = []
        for file in files {
            events.append(contentsOf: parseFile(at: file, fallbackModel: readConfiguredModel(root: root)))
        }

        events.sort { $0.timestamp < $1.timestamp }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfSevenDays = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let startOfThirtyDays = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday

        var today = CodexTokenTotals.zero
        var last7Days = CodexTokenTotals.zero
        var last30Days = CodexTokenTotals.zero
        var models: [String: CodexTokenTotals] = [:]
        var sessionTotals: [String: CodexTokenTotals] = [:]
        var latestEvent: UsageEvent?

        for event in events {
            if event.timestamp >= startOfThirtyDays {
                last30Days.add(event.totals)
                var modelTotals = models[event.model] ?? .zero
                modelTotals.add(event.totals)
                models[event.model] = modelTotals
            }
            if event.timestamp >= startOfSevenDays {
                last7Days.add(event.totals)
            }
            if event.timestamp >= startOfToday {
                today.add(event.totals)
            }

            var totals = sessionTotals[event.sessionID] ?? .zero
            totals.add(event.totals)
            sessionTotals[event.sessionID] = totals
            latestEvent = event
        }

        let currentSession = latestEvent.flatMap { sessionTotals[$0.sessionID] }
        let latestLimits = events.last(where: { $0.primaryRateLimit != nil || $0.secondaryRateLimit != nil })

        // Codex 的 input_tokens 含 cached_input_tokens，拆开映射：
        // inputTokens = 非缓存输入，cacheReadTokens = 缓存输入，两者相加还原原始 input
        let usageEntries = events.enumerated().map { index, event in
            UsageEntry(
                id: "codex-\(index)-\(event.timestamp.timeIntervalSince1970)",
                timestamp: event.timestamp,
                sessionId: event.sessionID,
                inputTokens: max(0, event.totals.inputTokens - event.totals.cachedInputTokens),
                outputTokens: event.totals.outputTokens,
                cacheCreationTokens: 0,
                cacheReadTokens: min(event.totals.cachedInputTokens, event.totals.inputTokens),
                costUsd: 0,
                model: event.model,
                messageId: "",
                requestId: "",
                mcpServers: [],
                skills: []
            )
        }

        return CodexUsageSnapshot(
            today: today,
            last7Days: last7Days,
            last30Days: last30Days,
            currentSession: currentSession,
            models: models,
            primaryRateLimit: latestLimits?.primaryRateLimit,
            secondaryRateLimit: latestLimits?.secondaryRateLimit,
            lastTokenAt: latestEvent?.timestamp,
            scannedFileCount: files.count,
            entries: usageEntries
        )
    }

    private struct UsageNumbers {
        var input = 0
        var cachedInput = 0
        var output = 0
        var reasoningOutput = 0
        var total = 0
        var hasTotal = false
        var hasAnyValue = false

        var derivedTotal: Int {
            hasTotal ? total : input + output
        }

        var isEmpty: Bool {
            !hasAnyValue || (input == 0 && cachedInput == 0 && output == 0 && reasoningOutput == 0 && total == 0)
        }

        func delta(from previous: UsageNumbers) -> UsageNumbers? {
            let values = UsageNumbers(
                input: input - previous.input,
                cachedInput: cachedInput - previous.cachedInput,
                output: output - previous.output,
                reasoningOutput: reasoningOutput - previous.reasoningOutput,
                total: derivedTotal - previous.derivedTotal,
                hasTotal: hasTotal,
                hasAnyValue: true
            )
            guard values.input >= 0,
                  values.cachedInput >= 0,
                  values.output >= 0,
                  values.reasoningOutput >= 0,
                  values.total >= 0 else { return nil }
            return values
        }

        init(
            input: Int = 0,
            cachedInput: Int = 0,
            output: Int = 0,
            reasoningOutput: Int = 0,
            total: Int = 0,
            hasTotal: Bool = false,
            hasAnyValue: Bool = false
        ) {
            self.input = input
            self.cachedInput = cachedInput
            self.output = output
            self.reasoningOutput = reasoningOutput
            self.total = total
            self.hasTotal = hasTotal
            self.hasAnyValue = hasAnyValue
        }

        func asTotals() -> CodexTokenTotals {
            CodexTokenTotals(
                inputTokens: input,
                cachedInputTokens: cachedInput,
                outputTokens: output,
                reasoningOutputTokens: reasoningOutput,
                totalTokens: max(0, derivedTotal),
                requestCount: 1
            )
        }
    }

    private struct UsageEvent {
        let timestamp: Date
        let sessionID: String
        let model: String
        let totals: CodexTokenTotals
        let primaryRateLimit: CodexRateLimitWindow?
        let secondaryRateLimit: CodexRateLimitWindow?
    }

    private func resolvedHomeDirectory() -> String {
        if let homeDirectory, !homeDirectory.isEmpty { return homeDirectory }
        if let configured = ProcessInfo.processInfo.environment["CODEX_HOME"], !configured.isEmpty {
            return configured
        }
        return (NSHomeDirectory() as NSString).appendingPathComponent(".codex")
    }

    private func jsonlFiles(root: String, fileManager: FileManager) -> [String] {
        var files: [String] = []
        let sessionsPath = (root as NSString).appendingPathComponent("sessions")
        if let enumerator = fileManager.enumerator(atPath: sessionsPath) {
            while let relative = enumerator.nextObject() as? String {
                if relative.hasSuffix(".jsonl") {
                    files.append((sessionsPath as NSString).appendingPathComponent(relative))
                }
            }
        }

        let archivedPath = (root as NSString).appendingPathComponent("archived_sessions")
        if let archived = try? fileManager.contentsOfDirectory(atPath: archivedPath) {
            files.append(contentsOf: archived
                .filter { $0.hasSuffix(".jsonl") }
                .map { (archivedPath as NSString).appendingPathComponent($0) })
        }
        return files.sorted()
    }

    private func readConfiguredModel(root: String) -> String {
        let path = (root as NSString).appendingPathComponent("config.toml")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return "Codex" }
        for line in content.split(whereSeparator: \.isNewline) {
            let value = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = value.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0] == "model" else { continue }
            let model = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if !model.isEmpty { return model }
        }
        return "Codex"
    }

    private func parseFile(at path: String, fallbackModel: String) -> [UsageEvent] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        let fallbackSessionID = (path as NSString).lastPathComponent
        var sessionID = fallbackSessionID
        var currentModel = fallbackModel
        var previousCumulative: UsageNumbers?
        var fallbackSeen = Set<String>()
        var events: [UsageEvent] = []

        for line in content.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { continue }

            let timestamp = parseDate(json["timestamp"] as? String) ?? Date.distantPast
            let type = json["type"] as? String ?? ""
            let payload = json["payload"] as? [String: Any] ?? [:]
            let payloadType = payload["type"] as? String ?? ""

            if type == "session_meta" {
                sessionID = stringValue(payload, keys: ["id", "session_id", "sessionId"]) ?? sessionID
            }

            if payloadType == "turn_context" || type == "turn_context" {
                currentModel = stringValue(payload, keys: ["model", "model_name", "modelName"])
                    ?? stringValue(json, keys: ["model", "model_name", "modelName"])
                    ?? currentModel
            }

            guard type == "event_msg", payloadType == "token_count",
                  let info = payload["info"] as? [String: Any]
            else { continue }

            let cumulative = usageNumbers(info["total_token_usage"] as? [String: Any])
            let last = usageNumbers(info["last_token_usage"] as? [String: Any])
            let delta: UsageNumbers?

            if let cumulative, !cumulative.isEmpty {
                if let previousCumulative {
                    delta = cumulative.delta(from: previousCumulative)
                } else {
                    delta = last.flatMap { $0.isEmpty ? nil : $0 } ?? cumulative
                }
                previousCumulative = cumulative
            } else {
                guard let last, !last.isEmpty else { continue }
                let key = "\(timestamp.timeIntervalSince1970):\(last.input):\(last.cachedInput):\(last.output):\(last.reasoningOutput):\(last.derivedTotal)"
                guard fallbackSeen.insert(key).inserted else { continue }
                delta = last
            }

            guard let delta, delta.derivedTotal > 0 else { continue }

            let limits = parseRateLimits(payload["rate_limits"] as? [String: Any] ?? info["rate_limits"] as? [String: Any])
            events.append(UsageEvent(
                timestamp: timestamp == .distantPast ? Date() : timestamp,
                sessionID: sessionID,
                model: currentModel,
                totals: delta.asTotals(),
                primaryRateLimit: limits.primary,
                secondaryRateLimit: limits.secondary
            ))
        }
        return events
    }

    private func usageNumbers(_ dictionary: [String: Any]?) -> UsageNumbers? {
        guard let dictionary else { return nil }
        let input = integerValue(dictionary["input_tokens"])
        let cached = integerValue(dictionary["cached_input_tokens"])
        let output = integerValue(dictionary["output_tokens"])
        let reasoning = integerValue(dictionary["reasoning_output_tokens"])
        let hasTotal = dictionary["total_tokens"] != nil
        let total = integerValue(dictionary["total_tokens"])
        let hasAny = ["input_tokens", "cached_input_tokens", "output_tokens", "reasoning_output_tokens", "total_tokens"]
            .contains { dictionary[$0] != nil }
        return UsageNumbers(
            input: input,
            cachedInput: cached,
            output: output,
            reasoningOutput: reasoning,
            total: total,
            hasTotal: hasTotal,
            hasAnyValue: hasAny
        )
    }

    private func parseRateLimits(_ dictionary: [String: Any]?) -> (primary: CodexRateLimitWindow?, secondary: CodexRateLimitWindow?) {
        guard let dictionary else { return (nil, nil) }
        return (
            parseRateLimitWindow(dictionary["primary"] as? [String: Any]),
            parseRateLimitWindow(dictionary["secondary"] as? [String: Any])
        )
    }

    private func parseRateLimitWindow(_ dictionary: [String: Any]?) -> CodexRateLimitWindow? {
        guard let dictionary,
              let usedPercent = doubleValue(dictionary["used_percent"]),
              let windowMinutes = integerValueOptional(dictionary["window_minutes"]),
              let resetsAt = doubleValue(dictionary["resets_at"])
        else { return nil }
        return CodexRateLimitWindow(
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }

    private func stringValue(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    private func integerValue(_ value: Any?) -> Int {
        if let value = value as? Int { return max(0, value) }
        if let value = value as? NSNumber { return max(0, value.intValue) }
        return 0
    }

    private func integerValueOptional(_ value: Any?) -> Int? {
        guard value != nil else { return nil }
        return integerValue(value)
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
