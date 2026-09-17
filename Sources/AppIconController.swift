import AppKit
import Combine
import Foundation

enum AppIconRendering {
    case nativeSquircle
    case squareArtwork
}

struct AppIconOption: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let filename: String
    let rendering: AppIconRendering
}

enum AppIconCatalog {
    static let defaultID = "c1-macos-squircle"

    static let all: [AppIconOption] = [
        AppIconOption(
            id: "a1-north-left",
            name: "北极星 · 左",
            detail: "单一方向感，暖黄星体从左下出现。",
            filename: "A1-north-star-lower-left.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "a1-aurora-left",
            name: "北极星 · 极光左",
            detail: "宽阔极光幕让方向逐渐显现，不使用星光粒子。",
            filename: "A1-aurora-left.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "a2-north-right",
            name: "北极星 · 右",
            detail: "同一意象的右下构图，用来比较视觉重心。",
            filename: "A2-north-star-lower-right.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "a2-aurora-right",
            name: "北极星 · 极光右",
            detail: "反向极光曲线与右下重心形成安静的平衡。",
            filename: "A2-aurora-right.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "b1-guide-left",
            name: "引导星 · 左",
            detail: "四向星芒，强调从噪音里找到方向。",
            filename: "B1-guiding-star-lower-left.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "b1-pulse-left",
            name: "引导星 · 脉冲左",
            detail: "两层宽磁场涟漪，表达从噪音里锁定方向。",
            filename: "B1-magnetic-pulse-left.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "b2-guide-right",
            name: "引导星 · 右",
            detail: "更强的方向符号，视觉重心位于右下。",
            filename: "B2-guiding-star-lower-right.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "b2-pulse-right",
            name: "引导星 · 脉冲右",
            detail: "反向信号场保留右侧构图与明确的聚焦感。",
            filename: "B2-magnetic-pulse-right.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "c1-growing-left",
            name: "生长星 · 原稿",
            detail: "薄荷绿与森林绿，表达稳定完成后的复利。",
            filename: "C1-growing-star-lower-left.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "c1-mist-left",
            name: "生长星 · 晨雾左",
            detail: "一股宽而柔的晨雾呼吸，表达缓慢持续生长。",
            filename: "C1-morning-mist-left.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "c2-growing-right",
            name: "生长星 · 右",
            detail: "生长星的右下构图，用来比较亲近感。",
            filename: "C2-growing-star-lower-right.png",
            rendering: .squareArtwork
        ),
        AppIconOption(
            id: "c2-mist-right",
            name: "生长星 · 晨雾右",
            detail: "晨雾从左侧回旋，为右下星体留出呼吸空间。",
            filename: "C2-morning-mist-right.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: defaultID,
            name: "生长星 · macOS",
            detail: "克制的 squircle 正式版，安静、清楚、耐看。",
            filename: "C1-macos-squircle.png",
            rendering: .nativeSquircle
        ),
        AppIconOption(
            id: "c1-alive-glow",
            name: "活星微光",
            detail: "边缘微光与三颗稀疏星尘，让它更有生命感。",
            filename: "C1-alive-glow.png",
            rendering: .nativeSquircle
        )
    ]

    static var defaultOption: AppIconOption {
        guard let option = all.first(where: { $0.id == defaultID }) else {
            preconditionFailure("AppIconCatalog.defaultID must exist in AppIconCatalog.all")
        }
        return option
    }

    static func option(id: String) -> AppIconOption? {
        all.first { $0.id == id }
    }

    static func validationIssues() -> [String] {
        var issues: [String] = []
        if Set(all.map(\.id)).count != all.count {
            issues.append("图标候选 ID 不唯一")
        }
        if Set(all.map(\.filename)).count != all.count {
            issues.append("图标候选文件名不唯一")
        }
        if option(id: defaultID) == nil {
            issues.append("默认图标候选不存在")
        }
        return issues
    }
}

enum AppIconSelectionError: LocalizedError {
    case missingResource(String)
    case unreadableResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(filename):
            "找不到图标资源：\(filename)。请重新构建 Better.app。"
        case let .unreadableResource(filename):
            "无法读取图标资源：\(filename)。文件可能已损坏。"
        }
    }
}

@MainActor
final class AppIconController: ObservableObject {
    static let selectionKey = "selectedAppIconID"

    @Published private(set) var selectedID: String
    @Published private(set) var currentImage: NSImage
    @Published private(set) var unavailableIDs: Set<String>
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let application: NSApplication
    private let imageCache: [String: NSImage]

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        application suppliedApplication: NSApplication? = nil
    ) {
        let application = suppliedApplication ?? NSApplication.shared
        self.defaults = defaults
        self.application = application

        let resourceDirectory = bundle.resourceURL?
            .appendingPathComponent("IconCandidates", isDirectory: true)
        var loaded: [String: NSImage] = [:]
        var unavailable: Set<String> = []

        for option in AppIconCatalog.all {
            do {
                loaded[option.id] = try Self.load(option, from: resourceDirectory)
            } catch {
                unavailable.insert(option.id)
            }
        }

        let storedID = defaults.string(forKey: Self.selectionKey)
        let requested = storedID.flatMap(AppIconCatalog.option(id:)) ?? AppIconCatalog.defaultOption
        let selected = loaded[requested.id] == nil ? AppIconCatalog.defaultOption : requested
        let fallback = bundle.url(forResource: "Better", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? application.applicationIconImage
            ?? NSImage(systemSymbolName: "star", accessibilityDescription: "Better")
            ?? NSImage(size: NSSize(width: 64, height: 64))
        let initialImage = loaded[selected.id] ?? fallback

        selectedID = selected.id
        currentImage = initialImage
        unavailableIDs = unavailable
        imageCache = loaded

        var startupErrors: [String] = []
        if let storedID, AppIconCatalog.option(id: storedID) == nil {
            startupErrors.append("上次选择的图标已不存在，已恢复正式默认图标。")
        } else if loaded[requested.id] == nil {
            startupErrors.append("无法加载上次选择的图标，已恢复正式默认图标。")
        }
        if loaded[AppIconCatalog.defaultID] == nil {
            startupErrors.append("图标候选资源未完整打包，请重新构建 Better.app。")
        }
        errorMessage = startupErrors.isEmpty ? nil : startupErrors.joined(separator: "\n")

        defaults.set(selected.id, forKey: Self.selectionKey)
        application.applicationIconImage = initialImage
    }

    func image(for option: AppIconOption) -> NSImage? {
        imageCache[option.id]
    }

    func select(_ option: AppIconOption) {
        guard let image = imageCache[option.id] else {
            errorMessage = AppIconSelectionError.missingResource(option.filename).localizedDescription
            return
        }
        selectedID = option.id
        currentImage = image
        application.applicationIconImage = image
        defaults.set(option.id, forKey: Self.selectionKey)
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private static func load(_ option: AppIconOption, from directory: URL?) throws -> NSImage {
        guard let url = directory?.appendingPathComponent(option.filename),
              FileManager.default.fileExists(atPath: url.path) else {
            throw AppIconSelectionError.missingResource(option.filename)
        }
        guard let source = NSImage(contentsOf: url) else {
            throw AppIconSelectionError.unreadableResource(option.filename)
        }
        switch option.rendering {
        case .nativeSquircle:
            return source
        case .squareArtwork:
            return normalizeSquareArtwork(source)
        }
    }

    private static func normalizeSquareArtwork(_ source: NSImage) -> NSImage {
        let size = NSSize(width: 1_024, height: 1_024)
        return NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current else { return false }
            context.imageInterpolation = .high
            let tile = bounds.insetBy(dx: 72, dy: 72)
            NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190).addClip()
            source.draw(
                in: tile,
                from: NSRect(origin: .zero, size: source.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
    }
}
