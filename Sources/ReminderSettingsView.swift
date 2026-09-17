import SwiftUI

struct ReminderSettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @State private var settings = ReminderSettings()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "保持可达，不制造焦虑",
                    title: "提醒与启动",
                    detail: "Better 可以随登录安静启动；提醒只负责把注意力带回选择和证据。"
                )

                BetterCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(BetterTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("登录后自动打开 Better")
                                    .font(.headline)
                                Text(launchAtLogin.statusDetail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Toggle(
                                "登录后自动打开 Better",
                                isOn: Binding(
                                    get: { launchAtLogin.desiredEnabled },
                                    set: { launchAtLogin.setEnabled($0) }
                                )
                            )
                            .labelsHidden()
                            .disabled(!launchAtLogin.isAvailable)
                        }

                        HStack {
                            BetterStatusPill(
                                title: launchAtLogin.statusTitle,
                                symbol: launchAtLogin.status == .enabled ? "checkmark.circle.fill" : "info.circle",
                                color: launchAtLogin.status == .enabled ? .green : BetterTheme.accent
                            )
                            Spacer()
                            if launchAtLogin.status == .requiresApproval {
                                Button("打开系统设置") {
                                    launchAtLogin.openSystemSettings()
                                }
                            }
                        }

                        if let error = launchAtLogin.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                BetterCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Toggle("启用每日提醒", isOn: $settings.enabled)
                            .font(.headline)

                        Divider()

                        TimeRow(
                            title: "开始提醒",
                            detail: "先选今天要新增的证据",
                            hour: $settings.startHour,
                            minute: $settings.startMinute,
                            enabled: settings.enabled
                        )
                        TimeRow(
                            title: "收尾提醒",
                            detail: "记录结果，然后停下来",
                            hour: $settings.reviewHour,
                            minute: $settings.reviewMinute,
                            enabled: settings.enabled
                        )

                        HStack {
                            Spacer()
                            Button("保存提醒") {
                                do { try store.updateReminders(settings) }
                                catch { store.present(error) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Text("专注计时结束通知不受每日提醒开关影响；第一次开始计时时，macOS 会请求通知权限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(maxWidth: 800, alignment: .leading)
        }
        .onAppear {
            settings = store.data.reminders
            launchAtLogin.refresh()
        }
    }
}

struct TimeRow: View {
    let title: String
    let detail: String
    @Binding var hour: Int
    @Binding var minute: Int
    let enabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("小时", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 70)
            Text(":")
            Picker("分钟", selection: $minute) {
                ForEach([0, 15, 30, 45], id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 70)
        }
        .disabled(!enabled)
    }
}
