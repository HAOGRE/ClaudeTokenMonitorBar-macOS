import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.haogre.claudetokenmonitor", category: "BookmarkManager")
private let bookmarkKey = "claudeProjectsBookmark"
private let codexBookmarkKey = "codexHomeBookmark"

/// Manages Security-Scoped Bookmark access to ~/.claude/projects
final class BookmarkManager {
    static let shared = BookmarkManager()
    private init() {}

    // 缓存已解析并 startAccessing 成功的 URL：
    // startAccessingSecurityScopedResource 每次调用都会占用一个内核引用且此处从不 stop，
    // 若每次刷新都重新解析会泄漏引用，数小时后耗尽导致读不到数据
    private var activeURL: URL?
    private var activeCodexURL: URL?

    // MARK: - Public API

    /// Returns the resolved ~/.claude/projects path if bookmark access is available, otherwise nil.
    func resolvedPath() -> String? {
        if let url = activeURL {
            return url.path
        }
        if let url = resolveBookmark() {
            activeURL = url
            return url.path
        }
        return nil
    }

    /// Returns true if a valid bookmark is already stored.
    var hasBookmark: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    var hasCodexBookmark: Bool {
        UserDefaults.standard.data(forKey: codexBookmarkKey) != nil
    }

    var defaultCodexPath: String {
        (realHomeDirectory() as NSString).appendingPathComponent(".codex")
    }

    func resolvedCodexPath() -> String? {
        if let url = activeCodexURL {
            return url.path
        }
        if let url = resolveCodexBookmark() {
            activeCodexURL = url
            return url.path
        }
        return nil
    }

    /// Presents NSOpenPanel pre-navigated to ~/.claude/projects and stores the resulting bookmark.
    /// Must be called on the main thread.
    @MainActor
    @discardableResult
    func requestAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.message = NSLocalizedString(
            "AI Token Monitor needs access to your local usage data folder to display usage statistics.",
            comment: "Sandbox permission panel message"
        )
        panel.prompt = NSLocalizedString("Grant Access", comment: "Sandbox permission panel button")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        // Pre-navigate to ~/.claude/projects if it exists, otherwise ~/.claude
        let home = realHomeDirectory()
        let projectsURL = URL(fileURLWithPath: home + "/.claude/projects")
        let claudeURL   = URL(fileURLWithPath: home + "/.claude")
        if FileManager.default.fileExists(atPath: projectsURL.path) {
            panel.directoryURL = projectsURL
        } else if FileManager.default.fileExists(atPath: claudeURL.path) {
            panel.directoryURL = claudeURL
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            logger.warning("User cancelled folder access panel")
            return false
        }

        activeURL = nil // 用户重新授权后，下次 resolvedPath 重新解析新 bookmark
        return storeBookmark(for: url)
    }

    @MainActor
    @discardableResult
    func requestCodexAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.message = NSLocalizedString(
            "AI Token Monitor needs access to the local Codex sessions folder to display token usage.",
            comment: "Codex sandbox permission panel message"
        )
        panel.prompt = NSLocalizedString("Grant Codex Access", comment: "Codex sandbox permission panel button")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        let codexURL = URL(fileURLWithPath: defaultCodexPath)
        if FileManager.default.fileExists(atPath: codexURL.path) {
            panel.directoryURL = codexURL
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            logger.warning("User cancelled Codex folder access panel")
            return false
        }

        activeCodexURL = nil
        return storeBookmark(for: url, key: codexBookmarkKey)
    }

    // MARK: - Private helpers

    private func storeBookmark(for url: URL) -> Bool {
        storeBookmark(for: url, key: bookmarkKey)
    }

    private func storeBookmark(for url: URL, key: String) -> Bool {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
            logger.info("Bookmark stored for \(url.path)")
            return true
        } catch {
            logger.error("Failed to create bookmark: \(error)")
            return false
        }
    }

    private func resolveBookmark() -> URL? {
        resolveBookmark(forKey: bookmarkKey)
    }

    private func resolveCodexBookmark() -> URL? {
        resolveBookmark(forKey: codexBookmarkKey)
    }

    private func resolveBookmark(forKey key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                _ = storeBookmark(for: url, key: key)
            }
            guard url.startAccessingSecurityScopedResource() else {
                logger.error("startAccessingSecurityScopedResource failed for \(url.path)")
                return nil
            }
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error)")
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    private func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
}
