import SwiftUI

struct AppIconLabView: View {
    @ObservedObject var iconController: AppIconController

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "品牌实验",
                    title: "图标实验室",
                    detail: "逐个比较，不必一次选死。点击候选会立即替换 Dock 与 Better 内的图标，下次启动仍会保留。"
                )

                BetterCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("怎样让星星真正“活起来”")
                            .font(.headline)
                        HStack(alignment: .top, spacing: 16) {
                            IconEffectNote(
                                symbol: "wind",
                                title: "极光幕",
                                detail: "一条宽阔光带让方向显现，不依赖星光粒子。"
                            )
                            IconEffectNote(
                                symbol: "dot.radiowaves.left.and.right",
                                title: "磁场涟漪",
                                detail: "两层宽脉冲表达锁定方向，不画细碎射线。"
                            )
                            IconEffectNote(
                                symbol: "water.waves",
                                title: "晨雾呼吸",
                                detail: "一股低处柔雾表达持续生长，不做烟火效果。"
                            )
                        }
                    }
                }

                if let errorMessage = iconController.errorMessage {
                    BetterCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("关闭") { iconController.clearError() }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("候选图标")
                        .font(.title3.weight(.semibold))
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(AppIconCatalog.all) { option in
                            AppIconOptionCard(option: option, iconController: iconController)
                        }
                    }
                }

                Text("运行时切换不会重写已签名的 Better.app；Finder 中的应用文件仍使用正式默认图标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }
}

private struct IconEffectNote: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppIconOptionCard: View {
    let option: AppIconOption
    @ObservedObject var iconController: AppIconController

    private var isSelected: Bool {
        iconController.selectedID == option.id
    }

    var body: some View {
        Button {
            iconController.select(option)
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = iconController.image(for: option) {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.quaternary)
                                .overlay(Image(systemName: "photo.badge.exclamationmark"))
                        }
                    }
                    .frame(width: 92, height: 92)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, BetterTheme.blue)
                            .background(.white, in: Circle())
                    }
                }

                Text(option.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(option.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isSelected ? "正在使用" : "点击试用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? BetterTheme.blue : BetterTheme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? BetterTheme.blue : Color.secondary.opacity(0.14), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(iconController.unavailableIDs.contains(option.id))
        .opacity(iconController.unavailableIDs.contains(option.id) ? 0.5 : 1)
        .accessibilityLabel("\(option.name)，\(isSelected ? "正在使用" : "点击试用")")
    }
}
