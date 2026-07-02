import AppKit
import SwiftUI
import ServiceManagement

@Observable
final class AppSettings {
    // MARK: - 显示项配置（可隐藏模块；Hero/限额/图表为固定模块不可隐藏）
    var showModelsSection: Bool {
        didSet { UserDefaults.standard.set(showModelsSection, forKey: "showModelsSection") }
    }
    var showTrendSection: Bool {
        didSet { UserDefaults.standard.set(showTrendSection, forKey: "showTrendSection") }
    }
    var showMcpSkillSection: Bool {
        didSet { UserDefaults.standard.set(showMcpSkillSection, forKey: "showMcpSkillSection") }
    }
    var showHeatmapSection: Bool {
        didSet { UserDefaults.standard.set(showHeatmapSection, forKey: "showHeatmapSection") }
    }

    // MARK: - 刷新间隔（秒）
    var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    static let refreshIntervalOptions = [3, 5, 10, 30, 60]



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
        showModelsSection   = defaults.object(forKey: "showModelsSection")   as? Bool ?? true
        showTrendSection    = defaults.object(forKey: "showTrendSection")    as? Bool ?? true
        showMcpSkillSection = defaults.object(forKey: "showMcpSkillSection") as? Bool ?? true
        showHeatmapSection  = defaults.object(forKey: "showHeatmapSection")  as? Bool ?? true
        refreshInterval     = defaults.object(forKey: "refreshInterval")     as? Int  ?? 5
        showDockIcon        = defaults.object(forKey: "showDockIcon")        as? Bool ?? false

        // 从系统读取开机启动的实际状态（以系统为准，不存 UserDefaults）
        launchAtLogin = SMAppService.mainApp.status == .enabled
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
