import AppKit
import SwiftUI

struct GitContextView: View {
    @ObservedObject var store: AppStore
    @StateObject private var git = GitContextService()
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom) {
                    PageHeader(
                        eyebrow: "明确授权的实现上下文",
                        title: "Git 上下文",
                        detail: "只读取你选择的本地仓库。不会扫描其他目录，不会访问远端，也不会修改代码。"
                    )
                    Spacer()
                    Button("选择本地仓库") { chooseRepository() }
                        .buttonStyle(.borderedProminent)
                        .disabled(git.isRefreshing || store.data.gitRepositories.count >= 8)
                }

                boundaryCard

                if let error = git.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }

                if store.data.gitRepositories.isEmpty {
                    EmptyCallout(
                        symbol: "externaldrive.badge.plus",
                        title: "还没有授权任何仓库",
                        detail: "选择一个真正对应当前押注的本地 Git 仓库。Better 只保存规范化路径和只读快照。",
                        actionTitle: "选择本地仓库",
                        action: chooseRepository
                    )
                } else {
                    HStack {
                        Text("已选择 \(store.data.gitRepositories.count)/8")
                            .font(.headline)
                        Text("启用 \(store.enabledGitRepositories.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if git.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("刷新全部") {
                            Task { await refreshAll() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(git.isRefreshing || store.enabledGitRepositories.isEmpty)
                    }

                    ForEach(store.data.gitRepositories) { repository in
                        GitRepositoryCard(
                            repository: repository,
                            isRefreshing: git.isRefreshing,
                            onToggle: { enabled in
                                do {
                                    try store.setGitRepositoryEnabled(repository.id, enabled: enabled)
                                    if enabled {
                                        Task { await refresh(repositoryID: repository.id) }
                                    }
                                } catch {
                                    store.present(error)
                                }
                            },
                            onRefresh: {
                                Task { await refresh(repositoryID: repository.id) }
                            },
                            onRemove: {
                                do { try store.removeGitRepository(repository.id) }
                                catch { store.present(error) }
                            }
                        )
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .task {
            if !store.enabledGitRepositories.isEmpty {
                await refreshAll()
            }
        }
    }

    private var boundaryCard: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 9) {
                Label("Git 不是用户价值证据", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text("分支、提交和工作区变化只能说明实现活动。它们不能证明产品已经发布、被用户使用，或产生了主动返回、承诺和付费。")
                    .font(.callout)
                Text("ahead/behind 只基于本地 upstream 引用；Better 不执行 fetch。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseRepository() {
        let panel = NSOpenPanel()
        panel.title = "选择 Better Coach 可以读取的 Git 仓库"
        panel.prompt = "添加仓库"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        git.clearError()
        statusMessage = nil
        Task {
            guard let snapshot = await git.inspect(path: url.path) else { return }
            do {
                try store.addGitRepository(snapshot: snapshot)
                statusMessage = "已添加 \(URL(fileURLWithPath: snapshot.rootPath).lastPathComponent)。"
            } catch {
                store.present(error)
            }
        }
    }

    private func refreshAll() async {
        statusMessage = nil
        let updates = await git.refresh(store.data.gitRepositories)
        do {
            try store.applyGitRefreshes(updates)
            if updates.allSatisfy({ $0.errorMessage == nil }), !updates.isEmpty {
                statusMessage = "已刷新 \(updates.count) 个本地仓库。"
            }
        } catch {
            store.present(error)
        }
    }

    private func refresh(repositoryID: UUID) async {
        guard let repository = store.data.gitRepositories.first(where: {
            $0.id == repositoryID && $0.enabled
        }) else { return }
        statusMessage = nil
        let updates = await git.refresh([repository])
        do {
            try store.applyGitRefreshes(updates)
            if updates.first?.errorMessage == nil {
                statusMessage = "已刷新 \(repository.displayName)。"
            }
        } catch {
            store.present(error)
        }
    }
}

private struct GitRepositoryCard: View {
    let repository: GitRepositoryWatch
    let isRefreshing: Bool
    let onToggle: (Bool) -> Void
    let onRefresh: () -> Void
    let onRemove: () -> Void

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.displayName)
                            .font(.title3.weight(.semibold))
                        Text(repository.rootPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Toggle("Agent 使用", isOn: Binding(
                        get: { repository.enabled },
                        set: onToggle
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help(repository.enabled ? "Coach 会在调用前刷新此仓库" : "此仓库不会进入 Coach 上下文")
                    Menu {
                        Button("刷新", action: onRefresh)
                            .disabled(!repository.enabled || isRefreshing)
                        Button("移除关注", role: .destructive, action: onRemove)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }

                if !repository.enabled {
                    Label("已禁用：不会刷新，也不会发送给 Coach。", systemImage: "pause.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let error = repository.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if let snapshot = repository.lastSnapshot {
                    HStack(spacing: 8) {
                        GitStatusChip(title: snapshot.branch, symbol: "point.topleft.down.to.point.bottomright.curvepath")
                        GitStatusChip(title: snapshot.shortHeadSHA, symbol: "number")
                        if let upstream = snapshot.upstream {
                            GitStatusChip(
                                title: "↑\(snapshot.aheadCount ?? 0) ↓\(snapshot.behindCount ?? 0)",
                                symbol: "arrow.up.arrow.down"
                            )
                            .help("相对本地 \(upstream)；未执行 fetch")
                        } else {
                            GitStatusChip(title: "无 upstream", symbol: "link.badge.plus")
                        }
                        Spacer()
                        Text(snapshot.capturedAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        GitStatusChip(title: "暂存 \(snapshot.stagedCount)", symbol: "tray.and.arrow.down")
                        GitStatusChip(title: "修改 \(snapshot.modifiedCount)", symbol: "pencil")
                        GitStatusChip(title: "未跟踪 \(snapshot.untrackedCount)", symbol: "questionmark.diamond")
                        GitStatusChip(
                            title: "冲突 \(snapshot.conflictCount)",
                            symbol: "exclamationmark.triangle",
                            color: snapshot.conflictCount > 0 ? .red : .secondary
                        )
                    }

                    if !snapshot.recentCommits.isEmpty {
                        Divider()
                        Text("最近本地提交")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(snapshot.recentCommits) { commit in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Text(commit.shortSHA)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tint)
                                Text(commit.subject)
                                    .lineLimit(1)
                                Spacer()
                                Text(commit.committedAt, format: .dateTime.month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if repository.lastError == nil {
                    Text("尚未取得 Git 快照。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct GitStatusChip: View {
    let title: String
    let symbol: String
    var color: Color = .secondary

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.08), in: Capsule())
    }
}
