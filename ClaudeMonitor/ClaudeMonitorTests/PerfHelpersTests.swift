//
//  PerfHelpersTests.swift
//  ClaudeMonitorTests
//
//  性能优化引入的归并 / 二分逻辑的正确性检查
//

import Foundation
import Testing
@testable import ClaudeTokenMonitorBar

private func entry(_ t: TimeInterval) -> UsageEntry {
    UsageEntry(
        id: UUID().uuidString,
        timestamp: Date(timeIntervalSince1970: t),
        sessionId: "",
        inputTokens: 1,
        outputTokens: 0,
        cacheCreationTokens: 0,
        cacheReadTokens: 0,
        costUsd: 0,
        model: "m",
        messageId: "",
        requestId: "",
        mcpServers: [],
        skills: []
    )
}

struct PerfHelpersTests {

    @Test func mergeSortedKeepsOrderAndCount() {
        let reader = TokenDataReader()
        let a = [entry(1), entry(3), entry(5)]
        let b = [entry(2), entry(4), entry(6)]

        let merged = reader.mergeSorted(a, b)
        #expect(merged.count == 6)
        #expect(merged.map(\.timestamp) == merged.map(\.timestamp).sorted())

        #expect(reader.mergeSorted(a, []).map(\.timestamp) == a.map(\.timestamp))
        #expect(reader.mergeSorted([], b).map(\.timestamp) == b.map(\.timestamp))
        #expect(reader.mergeSorted([], []).isEmpty)
    }

    @Test func lowerBoundFindsBoundaries() {
        let arr = [entry(10), entry(20), entry(20), entry(30)]
        func lb(_ t: TimeInterval) -> Int {
            MonitoringViewModel.lowerBound(arr, Date(timeIntervalSince1970: t))
        }
        #expect(lb(5) == 0)    // 全部 >= t
        #expect(lb(10) == 0)   // 命中首元素
        #expect(lb(20) == 1)   // 重复值取第一个
        #expect(lb(21) == 3)   // 落在中间
        #expect(lb(30) == 3)   // 命中末元素
        #expect(lb(35) == 4)   // 全部 < t
        #expect(MonitoringViewModel.lowerBound([], Date()) == 0)
    }
}
