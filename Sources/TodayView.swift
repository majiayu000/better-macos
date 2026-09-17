import SwiftUI

struct TodayView: View {
    @ObservedObject var store: AppStore
    let onManageBets: () -> Void
    let onOpenCoach: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "唯一焦点",
                    title: "今天只做这一件",
                    detail: "先决定结束后会新增什么证据，再开始行动。"
                )

                HStack(spacing: 10) {
                    BetterStatusPill(
                        title: store.data.currentFocus == nil ? "等待选择" : "焦点已锁定",
                        symbol: store.data.currentFocus == nil ? "circle.dashed" : "scope"
                    )
                    BetterStatusPill(
                        title: "\(store.data.evidence.count) 条证据",
                        symbol: "chart.line.uptrend.xyaxis",
                        color: BetterTheme.blue
                    )
                    Spacer()
                }

                if let focus = store.data.currentFocus {
                    CurrentFocusCard(
                        store: store,
                        focus: focus,
                        onReviewWithCoach: onOpenCoach
                    )
                } else if store.activeBets.isEmpty {
                    EmptyCallout(
                        symbol: "square.stack.3d.up.slash",
                        title: "先留下最多三条押注",
                        detail: "押注不是项目名，而是 7 天或 14 天后希望真实改变的结果。其余想法都去停车场。",
                        actionTitle: "管理押注",
                        action: onManageBets
                    )
                } else {
                    CoachContinuationCard(store: store, onOpenCoach: onOpenCoach)
                    FocusComposer(store: store)
                }

                EvidenceLadder(compact: true)
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct CoachContinuationCard: View {
    @ObservedObject var store: AppStore
    let onOpenCoach: () -> Void

    var body: some View {
        BetterCard {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: store.data.pendingReviewEvidenceID == nil
                      ? "bubble.left.and.sparkles"
                      : "checkmark.message.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.data.pendingReviewEvidenceID == nil
                         ? "继续和 Better Coach 聊"
                         : "刚才发生的事情还没有复盘")
                        .font(.headline)
                    Text(store.data.pendingReviewEvidenceID == nil
                         ? "它会接着上次的上下文，帮你判断此刻最值得推进什么。"
                         : "先把实际证据和阻碍交给 Coach，再决定下一次唯一行动。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("打开对话", action: onOpenCoach)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct FocusComposer: View {
    @ObservedObject var store: AppStore
    @State private var betID: UUID?
    @State private var action = ""
    @State private var expectedEvidence = ""
    @State private var kind: EvidenceKind = .attempt
    @State private var duration = 50

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("锁定今天的唯一行动")
                    .font(.title3.weight(.semibold))

                Picker("推进哪条押注", selection: $betID) {
                    Text("请选择").tag(UUID?.none)
                    ForEach(store.activeBets) { bet in
                        Text(bet.title).tag(Optional(bet.id))
                    }
                }

                if let betID, let bet = store.bet(id: betID) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前最危险的假设")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(bet.riskiestAssumption)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                TextField("一个专注段内可完成的行动", text: $action, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                HStack(alignment: .top, spacing: 14) {
                    Picker("证据类型", selection: $kind) {
                        ForEach(EvidenceKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .frame(width: 210)

                    TextField("结束后将新增的具体证据", text: $expectedEvidence, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                Text(kind.detail)
                    .font(.caption)
                    .foregroundStyle(kind.isExternal ? Color.accentColor : .secondary)

                Picker("专注时长", selection: $duration) {
                    Text("25 分钟").tag(25)
                    Text("50 分钟").tag(50)
                    Text("90 分钟").tag(90)
                }
                .pickerStyle(.segmented)

                HStack {
                    Spacer()
                    Button("锁定这件事") {
                        guard let betID else {
                            store.present(BetterStoreError.unknownBet)
                            return
                        }
                        do {
                            try store.createFocus(
                                betID: betID,
                                action: action,
                                expectedEvidence: expectedEvidence,
                                kind: kind,
                                durationMinutes: duration
                            )
                        } catch {
                            store.present(error)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            if betID == nil { betID = store.activeBets.first?.id }
        }
    }
}

struct CurrentFocusCard: View {
    @ObservedObject var store: AppStore
    let focus: FocusPlan
    let onReviewWithCoach: () -> Void
    @State private var showingFinish = false

    var bet: Bet? { store.bet(id: focus.betID) }

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(bet?.title ?? "当前押注")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text(focus.action)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Text(focus.evidenceKind.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.tint.opacity(0.1), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("完成后应该看到")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(focus.expectedEvidence)
                }

                Divider()

                if focus.isRunning {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("剩余时间")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FocusCountdownText(focus: focus)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        Spacer()
                        Button("结束并记录证据") { showingFinish = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                } else {
                    HStack {
                        Button("重新选择") {
                            do { try store.discardUnstartedFocus() }
                            catch { store.present(error) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("开始 \(focus.durationMinutes) 分钟专注") {
                            do { try store.startFocus() }
                            catch { store.present(error) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFinish) {
            FinishFocusSheet(
                store: store,
                isPresented: $showingFinish,
                onReviewWithCoach: onReviewWithCoach
            )
        }
    }
}

struct FocusCountdownText: View {
    let focus: FocusPlan

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedRemaining(at: context.date))
        }
    }

    private func formattedRemaining(at date: Date) -> String {
        guard let endsAt = focus.endsAt else { return "--:--" }
        let remaining = max(Int(endsAt.timeIntervalSince(date)), 0)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }
}

struct FinishFocusSheet: View {
    @ObservedObject var store: AppStore
    @Binding var isPresented: Bool
    let onReviewWithCoach: () -> Void
    @State private var actualEvidence = ""
    @State private var unresolved = ""
    @State private var adaptationNote = ""
    @State private var energyLevel = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("收尾，不再继续打磨")
                .font(.title2.weight(.bold))
            Text("如实写下发生了什么。没有得到证据也可以，但要写明原因。")
                .foregroundStyle(.secondary)

            TextField("实际新增的证据，或没有证据的具体原因", text: $actualEvidence, axis: .vertical)
                .lineLimit(4...7)
                .textFieldStyle(.roundedBorder)
            TextField("还有什么关键问题没有答案？", text: $unresolved, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            TextField("哪些阻碍、变化或现实约束应该影响下一天？", text: $adaptationNote, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)

            Picker("今天可用精力", selection: $energyLevel) {
                Text("1 很低").tag(1)
                Text("2").tag(2)
                Text("3 正常").tag(3)
                Text("4").tag(4)
                Text("5 很高").tag(5)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("继续当前专注") { isPresented = false }
                Spacer()
                Button("保存并结束") {
                    save(reviewWithCoach: false)
                }
                .buttonStyle(.bordered)
                Button("保存并和 Coach 复盘") {
                    save(reviewWithCoach: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func save(reviewWithCoach: Bool) {
        do {
            try store.completeFocus(
                actualEvidence: actualEvidence,
                unresolvedQuestion: unresolved,
                adaptationNote: adaptationNote,
                energyLevel: energyLevel
            )
            isPresented = false
            if reviewWithCoach {
                DispatchQueue.main.async { onReviewWithCoach() }
            }
        } catch {
            store.present(error)
        }
    }
}
