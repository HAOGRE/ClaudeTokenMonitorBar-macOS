import SwiftUI

struct SettingsView: View {
    var onDismiss: () -> Void = {}
    @Environment(MonitoringViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(isDark: colorScheme == .dark) }
    private var settings: AppSettings { AppSettings.shared }
    private var l10n: L10n { L10n.shared }
    @State private var codexAuthorized = BookmarkManager.shared.hasCodexBookmark

    var body: some View {
        VStack(spacing: 0) {
            // ── 标题栏 ──────────────────────────────────────────
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(theme.primaryGreen)
                Text(l10n.str(.settingsTitle))
                    .font(.headline)
                    .foregroundColor(theme.textMain)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textSecondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // ── 设置内容 ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {

                // 系统
                settingsSectionHeader(title: l10n.str(.sectionSystem), icon: "desktopcomputer")

                SettingsToggleRow(
                    icon: "power",
                    title: l10n.str(.launchAtLoginTitle),
                    subtitle: l10n.str(.launchAtLoginSubtitle),
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.launchAtLogin = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "dock.rectangle",
                    title: l10n.str(.showDockIconTitle),
                    subtitle: l10n.str(.showDockIconSubtitle),
                    isOn: Binding(
                        get: { settings.showDockIcon },
                        set: { settings.showDockIcon = $0 }
                    )
                )

                RefreshIntervalRow(
                    interval: Binding(
                        get: { settings.refreshInterval },
                        set: { newValue in
                            settings.refreshInterval = newValue
                            viewModel.restartAutoRefresh()
                        }
                    )
                )

                PeriodModeRow(
                    useCalendarPeriods: Binding(
                        get: { settings.useCalendarPeriods },
                        set: { newValue in
                            settings.useCalendarPeriods = newValue
                            viewModel.refreshData()
                        }
                    )
                )

                CodexAccessRow(isAuthorized: $codexAuthorized)

                Divider()


                // 显示项（可隐藏模块）
                settingsSectionHeader(title: l10n.str(.sectionDisplay), icon: "eye.fill")

                SettingsToggleRow(
                    icon: "chart.pie.fill",
                    title: l10n.str(.showModelsTitle),
                    subtitle: l10n.str(.showModelsSubtitle),
                    isOn: Binding(
                        get: { settings.showModelsSection },
                        set: { settings.showModelsSection = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: l10n.str(.showTrendTitle),
                    subtitle: l10n.str(.showTrendSubtitle),
                    isOn: Binding(
                        get: { settings.showTrendSection },
                        set: { settings.showTrendSection = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "puzzlepiece.extension.fill",
                    title: l10n.str(.showMcpSkillTitle),
                    subtitle: l10n.str(.showMcpSkillSubtitle),
                    isOn: Binding(
                        get: { settings.showMcpSkillSection },
                        set: { settings.showMcpSkillSection = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "square.grid.3x3.fill",
                    title: l10n.str(.showHeatmapTitle),
                    subtitle: l10n.str(.showHeatmapSubtitle),
                    isOn: Binding(
                        get: { settings.showHeatmapSection },
                        set: { settings.showHeatmapSection = $0 }
                    )
                )
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .frame(width: 340)
        .background(VisualEffectBackground())
    }

    private func settingsSectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(theme.textSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CodexAccessRow: View {
    @Binding var isAuthorized: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(isDark: colorScheme == .dark) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .foregroundColor(theme.primaryGreen)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.shared.str(.codexGrantAccess))
                    .font(.callout)
                    .foregroundColor(theme.textMain)
                Text(isAuthorized ? L10n.shared.str(.codexAccessGranted) : L10n.shared.str(.codexAccessRequired))
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Button {
                if BookmarkManager.shared.requestCodexAccess() {
                    isAuthorized = true
                }
            } label: {
                Image(systemName: isAuthorized ? "checkmark.circle.fill" : "folder.badge.plus")
                    .foregroundColor(isAuthorized ? theme.primaryGreen : theme.textSecondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(L10n.shared.str(.codexGrantAccess))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 刷新间隔选择行

private struct RefreshIntervalRow: View {
    @Binding var interval: Int
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(isDark: colorScheme == .dark) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(theme.primaryGreen)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.shared.str(.refreshIntervalTitle))
                    .font(.callout)
                    .foregroundColor(theme.textMain)
                Text(L10n.shared.str(.refreshIntervalSubtitle))
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Picker("", selection: $interval) {
                ForEach(AppSettings.refreshIntervalOptions, id: \.self) { sec in
                    Text(L10n.shared.refreshSec(sec)).tag(sec)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 72)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 周/月统计口径选择行

private struct PeriodModeRow: View {
    @Binding var useCalendarPeriods: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(isDark: colorScheme == .dark) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.circle.fill")
                .foregroundColor(theme.primaryGreen)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.shared.str(.periodModeTitle))
                    .font(.callout)
                    .foregroundColor(theme.textMain)
                Text(L10n.shared.str(.periodModeSubtitle))
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Picker("", selection: $useCalendarPeriods) {
                Text(L10n.shared.str(.periodModeRolling)).tag(false)
                Text(L10n.shared.str(.periodModeCalendar)).tag(true)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 设置行组件

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { Theme(isDark: colorScheme == .dark) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(theme.primaryGreen)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .foregroundColor(theme.textMain)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 2)
    }
}
