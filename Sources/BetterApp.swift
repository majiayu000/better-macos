import AppKit
import SwiftUI

@main
struct BetterApplication: App {
    @StateObject private var store: AppStore
    @StateObject private var launchAtLogin: LaunchAtLoginController
    @StateObject private var iconController: AppIconController

    init() {
        _store = StateObject(wrappedValue: AppStore())
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginController.shared)
        _iconController = StateObject(wrappedValue: AppIconController())
    }

    var body: some Scene {
        WindowGroup("Better", id: "main") {
            DashboardView(
                store: store,
                launchAtLogin: launchAtLogin,
                iconController: iconController
            )
                .frame(minWidth: 900, minHeight: 650)
                .tint(BetterTheme.accent)
                .task {
                    store.rescheduleReminders()
                    launchAtLogin.configureOnLaunch()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    store.reloadFromDisk()
                }
        }
        .defaultSize(width: 1080, height: 760)
        .windowToolbarStyle(.unifiedCompact)

        MenuBarExtra {
            MenuBarPanel(store: store)
        } label: {
                Image(systemName: store.data.currentFocus?.isRunning == true ? "star.fill" : "star")
                .accessibilityLabel("Better")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarPanel: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let focus = store.data.currentFocus {
                Text("今天只做这一件")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(focus.action)
                    .font(.headline)
                    .lineLimit(3)
                if focus.isRunning {
                    FocusCountdownText(focus: focus)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("已经选好，尚未开始")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("今天还没有唯一焦点")
                    .font(.headline)
                Text("先决定要新增什么证据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("打开 Better") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
    }
}
