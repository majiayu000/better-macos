import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    static let shared = LaunchAtLoginController()

    @Published private(set) var desiredEnabled: Bool
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let preferenceKey = "better.launchAtLogin.enabled"
    private let defaults: UserDefaults
    private let service: SMAppService

    init(defaults: UserDefaults = .standard, service: SMAppService = .mainApp) {
        self.defaults = defaults
        self.service = service
        desiredEnabled = defaults.object(forKey: preferenceKey) as? Bool ?? true
        status = service.status
    }

    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    var statusTitle: String {
        guard isAvailable else { return "开发启动不可用" }
        switch status {
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "等待系统批准"
        case .notRegistered:
            return desiredEnabled ? "尚未启用" : "已关闭"
        case .notFound:
            return desiredEnabled ? "等待首次注册" : "已关闭"
        @unknown default:
            return "状态未知"
        }
    }

    var statusDetail: String {
        guard isAvailable else {
            return "登录项只在 Better.app 中生效；SwiftPM 开发运行不会修改系统设置。"
        }
        switch status {
        case .enabled:
            return "登录 macOS 后会自动打开 Better 和菜单栏入口，但不会自动开始任何任务。"
        case .requiresApproval:
            return "macOS 需要你在“登录项与扩展”中批准 Better。"
        case .notRegistered:
            return desiredEnabled ? "Better 还没有成功注册为登录项。" : "Better 不会随登录自动打开。"
        case .notFound:
            return desiredEnabled
                ? "Better 尚未登记到系统登录项，应用会立即尝试完成首次注册。"
                : "Better 不会随登录自动打开。"
        @unknown default:
            return "无法确认当前登录项状态。"
        }
    }

    func configureOnLaunch() {
        refresh()
        guard isAvailable else { return }
        reconcile()
    }

    func setEnabled(_ enabled: Bool) {
        desiredEnabled = enabled
        defaults.set(enabled, forKey: preferenceKey)
        reconcile()
    }

    func refresh() {
        status = service.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func reconcile() {
        guard isAvailable else {
            errorMessage = "请从 Better.app 启动应用后再设置登录项。"
            return
        }

        do {
            if desiredEnabled {
                if status == .notRegistered || status == .notFound {
                    try service.register()
                }
            } else if status == .enabled || status == .requiresApproval {
                try service.unregister()
            }
            refresh()
            errorMessage = nil
        } catch {
            refresh()
            errorMessage = "无法更新登录项：\(error.localizedDescription)"
        }
    }
}
