import SwiftUI

struct BetterCoachView: View {
    @ObservedObject var store: AppStore
    let onChoose: () -> Void
    @StateObject private var coach = CodexCoachService()
    @StateObject private var git = GitContextService()
    @State private var message = ""
    @State private var gitContextError: String?
    @FocusState private var inputFocused: Bool

    private var pendingEvidence: EvidenceRecord? {
        guard let id = store.data.pendingReviewEvidenceID else { return nil }
        return store.data.evidence.first { $0.id == id }
    }

    private var threadArchives: [CoachThreadArchive] {
        store.data.coach.archivedThreads ?? []
    }

    private var isBusy: Bool { coach.isRunning || git.isRefreshing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "连续教练",
                    title: "Better Coach",
                    detail: "它记住押注和真实证据，和你一起收敛下一步；不会替你扩展任务清单。"
                )

                statusRow

                if store.data.coach.threadID == nil, let archive = threadArchives.first {
                    threadRotationCard(archive)
                }

                if let pendingEvidence {
                    pendingReviewCard(pendingEvidence)
                }

                conversation

                if let suggestion = store.data.coach.pendingSuggestion {
                    suggestionCard(suggestion)
                }

                composer
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            BetterStatusPill(
                title: store.data.coach.threadID == nil
                    ? (threadArchives.isEmpty ? "尚未建立对话" : "等待新周期连接")
                    : "上下文可继续",
                symbol: store.data.coach.threadID == nil ? "circle.dashed" : "link.circle.fill"
            )
            BetterStatusPill(
                title: "本地保留 \(store.data.coach.messages.count) 条消息",
                symbol: "externaldrive.fill",
                color: BetterTheme.blue
            )
            if !threadArchives.isEmpty {
                BetterStatusPill(
                    title: "已轮换 \(threadArchives.count) 次",
                    symbol: "arrow.triangle.2.circlepath"
                )
            }
            if !store.enabledGitRepositories.isEmpty {
                BetterStatusPill(
                    title: "Git \(store.enabledGitRepositories.count) 个",
                    symbol: "point.topleft.down.to.point.bottomright.curvepath",
                    color: BetterTheme.blue
                )
            }
            Spacer()
        }
    }

    private func threadRotationCard(_ archive: CoachThreadArchive) -> some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 9) {
                Label("旧对话已经完成交接", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(archive.reason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(archive.handoffSummary)
                    .font(.callout)
                Text("发送下一条消息时，Coach 会带着这份复盘和最近对话建立新线程。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pendingReviewCard(_ evidence: EvidenceRecord) -> some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 11) {
                Label("这次收尾还没有和 Coach 复盘", systemImage: "checkmark.message.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(evidence.action)
                    .font(.title3.weight(.semibold))
                reviewField("实际证据", evidence.actualEvidence)
                if !evidence.unresolvedQuestion.isEmpty {
                    reviewField("仍然未知", evidence.unresolvedQuestion)
                }
                if let adaptation = evidence.adaptationNote, !adaptation.isEmpty {
                    reviewField("现实变化", adaptation)
                }
                Text("发送下一条消息时，这些信息会自动进入上下文。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func reviewField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    @ViewBuilder
    private var conversation: some View {
        if store.data.coach.messages.isEmpty {
            EmptyCallout(
                symbol: "bubble.left.and.sparkles",
                title: "从刚刚发生的现实开始",
                detail: "你可以补充结果、阻碍或犹豫。Coach 会先理解情况，再决定是否需要生成下一步。"
            )
        } else {
            BetterCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("对话")
                        .font(.title3.weight(.semibold))
                    ForEach(store.data.coach.messages) { item in
                        CoachMessageBubble(message: item)
                    }
                }
            }
        }
    }

    private var composer: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("继续当前情况")
                    .font(.headline)

                TextField(
                    pendingEvidence == nil
                        ? "告诉 Coach 现在发生了什么，或你卡在哪里……"
                        : "补充这次结果，例如：我最意外的是……",
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(3...7)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .disabled(isBusy)

                if let status = coach.statusMessage {
                    Label(status, systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                if let error = coach.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                if let gitContextError {
                    Text(gitContextError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                HStack(spacing: 10) {
                    if store.data.currentFocus == nil,
                       !store.activeBets.isEmpty,
                       store.data.coach.pendingSuggestion == nil {
                        Button("生成下一步提案") { generateSuggestion() }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                    }
                    Spacer()
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button(
                        git.isRefreshing ? "正在刷新 Git…" : (coach.isRunning ? "Coach 正在思考…" : "发送")
                    ) { sendMessage() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: CodexFocusSuggestion) -> some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 13) {
                Label("Coach 的下一步提案", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(.tint)
                if let bet = store.bet(id: suggestion.betID) {
                    Text(bet.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(suggestion.action)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                reviewField("预期证据", suggestion.expectedEvidence)
                HStack {
                    Text(suggestion.evidenceKind.title)
                    Text("·")
                    Text("\(suggestion.durationMinutes) 分钟")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                Text(suggestion.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("放弃提案") {
                        do { try store.clearCoachSuggestion() }
                        catch { store.present(error) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("确认为唯一焦点") {
                        do {
                            try store.acceptCoachSuggestion()
                            onChoose()
                        } catch {
                            store.present(error)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func sendMessage() {
        let submitted = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submitted.isEmpty else { return }
        coach.clearMessages()
        git.clearError()
        gitContextError = nil
        message = ""

        Task {
            guard await refreshGitBeforeCoach() else {
                if message.isEmpty { message = submitted }
                return
            }
            let snapshot = store.data
            guard let result = await coach.send(message: submitted, from: snapshot) else {
                if message.isEmpty { message = submitted }
                return
            }
            do {
                try store.recordCoachExchange(
                    userText: submitted,
                    assistantText: result.assistantText,
                    threadID: result.threadID,
                    contextFingerprint: result.contextFingerprint,
                    rebuiltThread: result.rebuiltThread
                )
            } catch {
                store.present(error)
            }
        }
    }

    private func generateSuggestion() {
        coach.clearMessages()
        git.clearError()
        gitContextError = nil
        let request = "请根据我们已经讨论的情况，生成下一次唯一行动提案。"

        Task {
            guard await refreshGitBeforeCoach() else { return }
            let snapshot = store.data
            guard let result = await coach.generateSuggestion(from: snapshot) else { return }
            do {
                try store.recordCoachSuggestion(
                    result.suggestion,
                    userText: request,
                    assistantText: result.assistantText,
                    threadID: result.threadID,
                    contextFingerprint: result.contextFingerprint,
                    rebuiltThread: result.rebuiltThread
                )
            } catch {
                store.present(error)
            }
        }
    }

    private func refreshGitBeforeCoach() async -> Bool {
        let repositories = store.enabledGitRepositories
        guard !repositories.isEmpty else { return true }

        let namesByID = Dictionary(uniqueKeysWithValues: repositories.map { ($0.id, $0.displayName) })
        let updates = await git.refresh(repositories)
        do {
            try store.applyGitRefreshes(updates)
        } catch {
            store.present(error)
            return false
        }

        let failures = updates.compactMap { update -> String? in
            guard let error = update.errorMessage else { return nil }
            return "\(namesByID[update.repositoryID] ?? "未知仓库")：\(error)"
        }
        guard failures.isEmpty else {
            gitContextError = "Git 上下文刷新失败，本次 Coach 调用没有执行：\n" + failures.joined(separator: "\n")
            return false
        }
        gitContextError = nil
        return true
    }
}

private struct CoachMessageBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.role == .user ? "你" : "Better Coach")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(
                message.role == .user ? Color.accentColor.opacity(0.12) : BetterTheme.blue.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 12)
            )
            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }
}

struct CodexCoachCard: View {
    @ObservedObject var store: AppStore
    let onChoose: () -> Void
    @StateObject private var planner = CodexPlanningService()

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("让 Codex 安排下一天", systemImage: "sparkles")
                            .font(.title3.weight(.semibold))
                        Text("读取最近 14 条实际记录，只生成一个可确认的下一步。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if planner.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if store.data.currentFocus != nil {
                    Text("先完成并复盘当前焦点。实际证据回来以后，建议才会变化。")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else if let suggestion = planner.suggestion {
                    suggestionView(suggestion)
                } else {
                    Text("Codex 只会收到当前押注、证据门槛、最近结果、阻碍、未知问题和精力状态。它在只读沙箱中运行，不能直接修改 Better 数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let error = planner.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Spacer()
                        Button(planner.isRunning ? "Codex 正在规划…" : "生成下一天建议") {
                            Task { await planner.generate(from: store.data) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(planner.isRunning || store.data.currentFocus != nil)
                    }
                }
            }
        }
    }

    private func suggestionView(_ suggestion: CodexFocusSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bet = store.bet(id: suggestion.betID) {
                Text(bet.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            Text(suggestion.action)
                .font(.headline)
            VStack(alignment: .leading, spacing: 3) {
                Text("预期证据")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(suggestion.expectedEvidence)
            }
            HStack {
                Text(suggestion.evidenceKind.title)
                Text("·")
                Text("\(suggestion.durationMinutes) 分钟")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)

            Text(suggestion.rationale)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("重新生成") {
                    planner.clearSuggestion()
                    Task { await planner.generate(from: store.data) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("采用为下一天唯一行动") {
                    do {
                        try store.acceptCodexSuggestion(suggestion)
                        planner.clearSuggestion()
                        onChoose()
                    } catch {
                        store.present(error)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
