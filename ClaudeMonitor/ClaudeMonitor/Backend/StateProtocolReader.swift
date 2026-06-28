import Foundation
import os.log

// MARK: - v4 State Protocol Models

struct V4StateProtocol: Codable, Sendable {
    let schema_version: String?
    let generated_at: String?
    let confidence: String?
    let stale: Bool?
    let plan: String?
    let limits: V4Limits?
    let local: V4Local?
    let local_history: V4LocalHistory?
}

struct V4Limits: Codable, Sendable {
    let five_hour: V4LimitDetail?
}

struct V4LimitDetail: Codable, Sendable {
    let used_percentage: Double?
    let tokens_used: Int?
    let token_limit: Int?
    let resets_at: String?
}

struct V4Local: Codable, Sendable {
    let is_active: Bool?
    let tokens: V4Tokens?
    let cost_usd: Double?
}

struct V4Tokens: Codable, Sendable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
    let total_tokens: Int?
}

struct V4LocalHistory: Codable, Sendable {
    let total_tokens: Int?
    let total_cost_usd: Double?
}

// MARK: - Reader

actor StateProtocolReader {
    private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "state_reader")
    private let stateFilePath: String
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir {
            self.stateFilePath = String(cString: homeDir) + "/.claude-monitor/state/latest.json"
        } else if let envHome = ProcessInfo.processInfo.environment["HOME"] {
            self.stateFilePath = envHome + "/.claude-monitor/state/latest.json"
        } else {
            self.stateFilePath = home + "/.claude-monitor/state/latest.json"
        }
    }
    
    func readState() -> V4StateProtocol? {
        guard FileManager.default.fileExists(atPath: stateFilePath) else {
            logger.info("State file not found at \(self.stateFilePath)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: stateFilePath))
            let decoder = JSONDecoder()
            let state = try decoder.decode(V4StateProtocol.self, from: data)
            return state
        } catch {
            logger.error("Failed to parse state file: \(error.localizedDescription)")
            return nil
        }
    }
}
