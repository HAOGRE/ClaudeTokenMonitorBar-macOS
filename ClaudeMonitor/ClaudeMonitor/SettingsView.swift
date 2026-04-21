import SwiftUI

struct SettingsView: View {
    var onDismiss: () -> Void = {}
    @Environment(MonitoringViewModel.self) private var viewModel
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        VStack(spacing: 0) {
            // ── 标题栏 ──────────────────────────────────────────
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.accentColor)
                Text("设置")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
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
                settingsSectionHeader(title: "系统", icon: "desktopcomputer")

                SettingsToggleRow(
                    icon: "power",
                    iconColor: .green,
                    title: "开机启动",
                    subtitle: "登录后自动启动 Claude 用量监控",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.launchAtLogin = $0 }
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

                Divider()

                // 显示项
                settingsSectionHeader(title: "显示项", icon: "eye.fill")

                SettingsToggleRow(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "项目成本 TOP 5",
                    subtitle: "显示成本最高的 5 个项目",
                    isOn: Binding(
                        get: { settings.showProjectSection },
                        set: { settings.showProjectSection = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "clock.fill",
                    iconColor: .orange,
                    title: "最近记录",
                    subtitle: "显示最近 5 条使用记录",
                    isOn: Binding(
                        get: { settings.showRecentSection },
                        set: { settings.showRecentSection = $0 }
                    )
                )

                SettingsToggleRow(
                    icon: "chart.bar.fill",
                    iconColor: .purple,
                    title: "30 天趋势",
                    subtitle: "显示近 30 天的成本趋势图",
                    isOn: Binding(
                        get: { settings.showChartSection },
                        set: { settings.showChartSection = $0 }
                    )
                )
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .frame(width: 340)
        .background(Color(.windowBackgroundColor))
    }

    private func settingsSectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 刷新间隔选择行

private struct RefreshIntervalRow: View {
    @Binding var interval: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.cyan)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("刷新间隔")
                    .font(.callout)
                Text("数据自动刷新的时间间隔")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $interval) {
                ForEach(AppSettings.refreshIntervalOptions, id: \.self) { sec in
                    Text("\(sec) 秒").tag(sec)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 72)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 设置行组件

private struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .imageScale(.medium)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
