import AppKit
import SwiftUI
import ServiceManagement

@Observable
final class AppSettings {
    // MARK: - 显示项配置
    var showProjectSection: Bool {
        didSet { UserDefaults.standard.set(showProjectSection, forKey: "showProjectSection") }
    }
    var showRecentSection: Bool {
        didSet { UserDefaults.standard.set(showRecentSection, forKey: "showRecentSection") }
    }
    var showChartSection: Bool {
        didSet { UserDefaults.standard.set(showChartSection, forKey: "showChartSection") }
    }

    // MARK: - 刷新间隔（秒）
    var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    static let refreshIntervalOptions = [3, 5, 10, 30, 60]

    // MARK: - 语言
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            L10n.shared.language = language
        }
    }

    // MARK: - Dock 图标
    var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
            NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        }
    }

    // MARK: - 开机启动
    var launchAtLogin: Bool {
        didSet {
            guard !applyingLaunchAtLogin, oldValue != launchAtLogin else { return }
            applyLaunchAtLogin(launchAtLogin)
        }
    }
    private var applyingLaunchAtLogin = false

    static let shared = AppSettings()

    private init() {
        let defaults = UserDefaults.standard
        // 首次启动默认全部显示
        showProjectSection = defaults.object(forKey: "showProjectSection") as? Bool ?? true
        showRecentSection  = defaults.object(forKey: "showRecentSection")  as? Bool ?? true
        showChartSection   = defaults.object(forKey: "showChartSection")   as? Bool ?? true
        refreshInterval    = defaults.object(forKey: "refreshInterval")    as? Int  ?? 5
        showDockIcon       = defaults.object(forKey: "showDockIcon")       as? Bool ?? false

        let savedLang = defaults.string(forKey: "appLanguage") ?? ""
        language = AppLanguage(rawValue: savedLang) ?? .chinese

        // 从系统读取开机启动的实际状态（以系统为准，不存 UserDefaults）
        launchAtLogin = SMAppService.mainApp.status == .enabled

        L10n.shared.language = language
    }

    // MARK: - 开机启动实现

    private func applyLaunchAtLogin(_ enable: Bool) {
        applyingLaunchAtLogin = true
        defer { applyingLaunchAtLogin = false }
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 注册失败时回滚到系统实际状态
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
