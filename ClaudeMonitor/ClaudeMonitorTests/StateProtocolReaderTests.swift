import Testing
import Foundation
@testable import ClaudeTokenMonitorBar

struct StateProtocolReaderTests {
    
    @Test func testParseValidStateJSON() async throws {
        let jsonContent = """
        {
          "schema_version": "1.0",
          "generated_at": "2026-06-28T14:11:49.212835+00:00",
          "confidence": "local_estimate",
          "plan": "custom",
          "stale": false,
          "limits": {
            "five_hour": {
              "used_percentage": 75.5,
              "tokens_used": 7550,
              "token_limit": 10000,
              "resets_at": "in 2 hours"
            },
            "seven_day": {
              "used_percentage": 42.0,
              "tokens_used": 420000,
              "token_limit": 1000000,
              "resets_at": "in 3 days"
            }
          },
          "local": {
            "is_active": true,
            "cost_usd": 12.34
          },
          "local_history": {
            "total_tokens": 123456,
            "total_cost_usd": 12.34
          }
        }
        """
        
        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("latest_test.json")
        try jsonContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        let reader = StateProtocolReader(customPath: tempFile.path)
        let state = await reader.readState()
        
        // Clean up
        try? FileManager.default.removeItem(at: tempFile)
        
        // Verify
        #expect(state != nil)
        #expect(state?.schema_version == "1.0")
        #expect(state?.plan == "custom")
        #expect(state?.limits?.five_hour?.used_percentage == 75.5)
        #expect(state?.limits?.five_hour?.tokens_used == 7550)
        #expect(state?.limits?.five_hour?.token_limit == 10000)
        #expect(state?.limits?.five_hour?.resets_at == "in 2 hours")

        #expect(state?.limits?.seven_day?.used_percentage == 42.0)
        #expect(state?.limits?.seven_day?.token_limit == 1000000)

        #expect(state?.local?.is_active == true)
        #expect(state?.local?.cost_usd == 12.34)
        
        #expect(state?.local_history?.total_tokens == 123456)
        #expect(state?.local_history?.total_cost_usd == 12.34)
    }
    
    @Test func testParseInvalidJSONReturnsNil() async throws {
        let jsonContent = """
        {
          "schema_version": "1.0",
          "invalid_json
        """
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("invalid_test.json")
        try jsonContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        let reader = StateProtocolReader(customPath: tempFile.path)
        let state = await reader.readState()
        
        try? FileManager.default.removeItem(at: tempFile)
        
        #expect(state == nil)
    }
    
    @Test func testMissingFileReturnsNil() async throws {
        let reader = StateProtocolReader(customPath: "/tmp/this_file_does_not_exist_claudemonitor.json")
        let state = await reader.readState()
        #expect(state == nil)
    }
}
