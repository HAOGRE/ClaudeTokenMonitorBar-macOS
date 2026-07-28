import Foundation
import Testing
@testable import ClaudeTokenMonitorBar

struct TokenDataReaderTests {
    @Test func estimatesOpus5CostWhenJsonlDoesNotProvideCost() throws {
        let directory = try makeProjectsDirectory(jsonl: """
        {"type":"assistant","timestamp":"2026-07-28T12:00:00Z","message":{"id":"opus-5-message","model":"claude-opus-5","usage":{"input_tokens":1000000,"output_tokens":1000000,"cache_creation_input_tokens":1000000,"cache_read_input_tokens":1000000}}}
        """)
        defer { try? FileManager.default.removeItem(at: directory) }

        let entries = TokenDataReader(dataDirectory: directory.path).loadAllData().allEntries

        #expect(entries.count == 1)
        #expect(entries[0].model == "claude-opus-5")
        #expect(entries[0].costUsd == 36.75)
    }

    @Test func estimatesSonnet5CostUsingTheEntryDate() throws {
        let directory = try makeProjectsDirectory(jsonl: """
        {"type":"assistant","timestamp":"2026-08-31T12:00:00Z","message":{"id":"sonnet-5-intro","model":"claude-sonnet-5","usage":{"input_tokens":1000000}}}
        {"type":"assistant","timestamp":"2026-09-01T00:00:00Z","message":{"id":"sonnet-5-standard","model":"claude-sonnet-5","usage":{"input_tokens":1000000}}}
        """)
        defer { try? FileManager.default.removeItem(at: directory) }

        let entries = TokenDataReader(dataDirectory: directory.path).loadAllData().allEntries
        let costs = Dictionary(uniqueKeysWithValues: entries.map { ($0.messageId, $0.costUsd) })

        #expect(costs["sonnet-5-intro"] == 2.0)
        #expect(costs["sonnet-5-standard"] == 3.0)
    }

    private func makeProjectsDirectory(jsonl: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("token-reader-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try jsonl.write(to: project.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8)
        return root
    }
}
