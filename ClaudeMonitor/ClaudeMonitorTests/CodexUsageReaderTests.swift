import Foundation
import Testing
@testable import ClaudeTokenMonitorBar

struct CodexUsageReaderTests {
    private let now = Date(timeIntervalSince1970: 1_783_684_800) // 2026-07-10T12:00:00Z

    @Test func cumulativeTokenEventsAreDeduplicated() throws {
        let fixture = """
        {"type":"session_meta","timestamp":"2026-07-10T11:00:00Z","payload":{"id":"session-1"}}
        {"type":"turn_context","timestamp":"2026-07-10T11:01:00Z","payload":{"type":"turn_context","model":"gpt-5.4-codex"}}
        {"type":"event_msg","timestamp":"2026-07-10T11:02:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":800,"cached_input_tokens":600,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":1050},"last_token_usage":{"input_tokens":800,"cached_input_tokens":600,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":1050}},"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1783700000},"secondary":{"used_percent":4.0,"window_minutes":10080,"resets_at":1784200000}}}}
        {"type":"event_msg","timestamp":"2026-07-10T11:02:01Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":800,"cached_input_tokens":600,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":1050},"last_token_usage":{"input_tokens":800,"cached_input_tokens":600,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":1050}}}}
        {"type":"event_msg","timestamp":"2026-07-10T11:03:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1100,"cached_input_tokens":800,"output_tokens":400,"reasoning_output_tokens":100,"total_tokens":1600},"last_token_usage":{"input_tokens":300,"cached_input_tokens":200,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":550}}}}
        """
        let home = try makeCodexHome(jsonl: fixture)
        let snapshot = try #require(CodexUsageReader(homeDirectory: home).loadSnapshot(now: now))

        #expect(snapshot.today.totalTokens == 1600)
        #expect(snapshot.today.inputTokens == 1100)
        #expect(snapshot.today.cachedInputTokens == 800)
        #expect(snapshot.today.outputTokens == 400)
        #expect(snapshot.today.reasoningOutputTokens == 100)
        #expect(snapshot.today.requestCount == 2)
        #expect(snapshot.models["gpt-5.4-codex"]?.totalTokens == 1600)
        #expect(snapshot.primaryRateLimit?.usedPercent == 12)
        #expect(snapshot.secondaryRateLimit?.windowMinutes == 10080)
    }

    @Test func archivedSessionsAndNullRateLimitsAreSupported() throws {
        let root = try makeCodexHome(jsonl: "")
        let archived = URL(fileURLWithPath: root).appendingPathComponent("archived_sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
        let line = """
        {"type":"session_meta","timestamp":"2026-07-09T10:00:00Z","payload":{"id":"archived-session"}}
        {"type":"event_msg","timestamp":"2026-07-09T10:01:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":25,"total_tokens":125},"last_token_usage":{"input_tokens":100,"output_tokens":25,"total_tokens":125}},"rate_limits":null}}
        """
        try line.write(to: archived.appendingPathComponent("archived.jsonl"), atomically: true, encoding: .utf8)

        let snapshot = try #require(CodexUsageReader(homeDirectory: root).loadSnapshot(now: now))
        #expect(snapshot.last7Days.totalTokens == 125)
        #expect(snapshot.last30Days.totalTokens == 125)
        #expect(snapshot.scannedFileCount == 2)
        #expect(snapshot.primaryRateLimit == nil)
        #expect(snapshot.secondaryRateLimit == nil)
    }

    @Test func configuredModelIsUsedWhenTurnContextIsMissing() throws {
        let fixture = """
        {"type":"session_meta","timestamp":"2026-07-10T09:00:00Z","payload":{"id":"config-session"}}
        {"type":"event_msg","timestamp":"2026-07-10T09:01:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"output_tokens":5,"total_tokens":25},"last_token_usage":{"input_tokens":20,"output_tokens":5,"total_tokens":25}}}}
        """
        let root = try makeCodexHome(jsonl: fixture)
        try "model = \"gpt-configured\"\n".write(
            to: URL(fileURLWithPath: root).appendingPathComponent("config.toml"),
            atomically: true,
            encoding: .utf8
        )

        let snapshot = try #require(CodexUsageReader(homeDirectory: root).loadSnapshot(now: now))
        #expect(snapshot.models["gpt-configured"]?.totalTokens == 25)
    }

    @Test func missingCodexHomeReturnsNil() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-codex-\(UUID().uuidString)").path
        #expect(CodexUsageReader(homeDirectory: path).loadSnapshot(now: now) == nil)
    }

    @Test func codexRateIgnoresFirstSampleAndCounterResets() {
        let current = CodexTokenTotals(
            inputTokens: 300,
            cachedInputTokens: 100,
            outputTokens: 80,
            totalTokens: 380,
            requestCount: 1
        )
        let first = MonitoringViewModel.codexRate(previous: nil, current: current, elapsed: 5)
        #expect(first.inputPerSec == 0)
        #expect(first.outputPerSec == 0)

        let previous = CodexTokenTotals(inputTokens: 200, outputTokens: 40, totalTokens: 240)
        let rate = MonitoringViewModel.codexRate(previous: previous, current: current, elapsed: 5)
        #expect(rate.inputPerSec == 20)
        #expect(rate.outputPerSec == 8)

        let reset = MonitoringViewModel.codexRate(
            previous: current,
            current: CodexTokenTotals(inputTokens: 10, outputTokens: 2, totalTokens: 12),
            elapsed: 5
        )
        #expect(reset.inputPerSec == 0)
        #expect(reset.outputPerSec == 0)
    }

    private func makeCodexHome(jsonl: String) throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-reader-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent("sessions/2026/07/10", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try jsonl.write(to: sessions.appendingPathComponent("rollout-test.jsonl"), atomically: true, encoding: .utf8)
        return root.path
    }
}
