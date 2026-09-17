import SwiftUI

struct BetsView: View {
    @ObservedObject var store: AppStore
    @State private var showingNewBet = false
    @State private var editingBet: Bet?
    @State private var reviewingBet: Bet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(
                        eyebrow: "滚动周期",
                        title: "最多三条当前押注",
                        detail: "只固定 7 天或 14 天的结果与证据门槛；每天的行动根据现实重新选择。"
                    )
                    Spacer()
                    Button("新增押注") { showingNewBet = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.activeBets.count >= 3)
                }

                if store.activeBets.isEmpty {
                    EmptyCallout(
                        symbol: "square.stack.3d.up",
                        title: "当前没有押注",
                        detail: "从真正存在外部约束、能在 7 天或 14 天内验证的一条线开始。"
                    )
                } else {
                    ForEach(store.activeBets) { bet in
                        BetCard(
                            store: store,
                            bet: bet,
                            onEdit: { editingBet = bet },
                            onReview: { reviewingBet = bet }
                        )
                    }
                }

                if !store.parkedBets.isEmpty {
                    Text("已停放的押注")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(store.parkedBets) { bet in
                        BetterCard {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(bet.title).font(.headline)
                                    Text(bet.sixWeekOutcome)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("重新激活") {
                                    do { try store.reactivateBet(bet.id) }
                                    catch { store.present(error) }
                                }
                                .disabled(store.activeBets.count >= 3)
                            }
                        }
                    }
                }

                if !store.completedBets.isEmpty {
                    Text("已完成的押注")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(store.completedBets) { bet in
                        BetterCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(bet.title).font(.headline)
                                    Spacer()
                                    if let completedAt = bet.completedAt {
                                        Text(completedAt, format: .dateTime.year().month().day())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(bet.sixWeekOutcome)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !store.data.cycleReviews.isEmpty {
                    Text("最近周期复盘")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(Array(store.data.cycleReviews.prefix(8))) { review in
                        CycleReviewHistoryCard(review: review)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .sheet(isPresented: $showingNewBet) {
            NewBetSheet(store: store, isPresented: $showingNewBet)
        }
        .sheet(item: $editingBet) { bet in
            EditBetSheet(store: store, bet: bet, isPresented: Binding(
                get: { editingBet != nil },
                set: { if !$0 { editingBet = nil } }
            ))
        }
        .sheet(item: $reviewingBet) { bet in
            BetCycleReviewSheet(store: store, bet: bet, isPresented: Binding(
                get: { reviewingBet != nil },
                set: { if !$0 { reviewingBet = nil } }
            ))
        }
    }
}

struct BetCard: View {
    @ObservedObject var store: AppStore
    let bet: Bet
    let onEdit: () -> Void
    let onReview: () -> Void

    private var isDue: Bool { bet.isReviewDue() }

    private var remainingDays: Int {
        max(
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: .now),
                to: Calendar.current.startOfDay(for: bet.reviewDate)
            ).day ?? 0,
            0
        )
    }

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bet.title)
                        .font(.title3.weight(.semibold))
                    Text("\(bet.resolvedHorizonDays) 天")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.1), in: Capsule())
                    Text(isDue ? "已到复盘日" : "剩余 \(remainingDays) 天")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isDue ? Color.orange : .secondary)
                    Spacer()
                    Menu {
                        Button("编辑押注", action: onEdit)
                        Button(isDue ? "开始周期复盘" : "提前复盘", action: onReview)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("本周期希望改变")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bet.sixWeekOutcome)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("周期证据门槛 · \(bet.reviewDate, format: .dateTime.month().day())复盘")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bet.evidenceGoal ?? bet.sixWeekOutcome)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("最危险的假设")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bet.riskiestAssumption)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                if isDue {
                    HStack {
                        Text("不要自动续期。先看当期证据，再决定下一周期。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("开始周期复盘", action: onReview)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

struct CycleReviewHistoryCard: View {
    let review: BetCycleReview

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(review.betTitle)
                        .font(.headline)
                    Text(review.decision.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.1), in: Capsule())
                    Spacer()
                    Text(review.reviewedAt, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(review.conclusion)
                HStack(spacing: 12) {
                    Text("证据 \(review.evidenceCount) 条")
                    Text("外部证据 \(review.externalEvidenceCount) 条")
                    if let strongest = review.strongestEvidenceKind {
                        Text("最强：\(strongest.title)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct EditBetSheet: View {
    @ObservedObject var store: AppStore
    let bet: Bet
    @Binding var isPresented: Bool
    @State private var title: String
    @State private var outcome: String
    @State private var assumption: String
    @State private var evidenceGoal: String
    @State private var horizonDays: Int

    init(store: AppStore, bet: Bet, isPresented: Binding<Bool>) {
        self.store = store
        self.bet = bet
        _isPresented = isPresented
        _title = State(initialValue: bet.title)
        _outcome = State(initialValue: bet.sixWeekOutcome)
        _assumption = State(initialValue: bet.riskiestAssumption)
        _evidenceGoal = State(initialValue: bet.evidenceGoal ?? bet.sixWeekOutcome)
        _horizonDays = State(initialValue: bet.resolvedHorizonDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑当前押注")
                .font(.title2.weight(.bold))
            Text("编辑不会重置当前周期。已经到期的押注仍需要完成复盘。")
                .foregroundStyle(.secondary)

            Picker("周期", selection: $horizonDays) {
                Text("7 天验证").tag(7)
                Text("14 天推进").tag(14)
            }
            .pickerStyle(.segmented)
            TextField("押注名称", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("周期结束时，什么真实结果会发生变化？", text: $outcome, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            TextField("达到什么证据，才算这次押注成立？", text: $evidenceGoal, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            TextField("现在最可能让这件事失败的假设是什么？", text: $assumption, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { isPresented = false }
                Spacer()
                Button("保存修改") {
                    do {
                        try store.updateBet(
                            bet.id,
                            title: title,
                            outcome: outcome,
                            assumption: assumption,
                            horizonDays: horizonDays,
                            evidenceGoal: evidenceGoal
                        )
                        isPresented = false
                    } catch {
                        store.present(error)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600)
    }
}

struct BetCycleReviewSheet: View {
    @ObservedObject var store: AppStore
    let bet: Bet
    @Binding var isPresented: Bool
    @State private var conclusion = ""
    @State private var decision: BetCycleDecision = .continueBet
    @State private var adjustedOutcome: String
    @State private var adjustedEvidenceGoal: String
    @State private var adjustedAssumption: String
    @State private var adjustedHorizonDays: Int

    private var evidence: [EvidenceRecord] { store.cycleEvidence(for: bet.id) }
    private var externalEvidenceCount: Int { evidence.filter { $0.kind.isExternal }.count }
    private var strongestKind: EvidenceKind? {
        evidence.max { $0.kind.strength < $1.kind.strength }?.kind
    }

    init(store: AppStore, bet: Bet, isPresented: Binding<Bool>) {
        self.store = store
        self.bet = bet
        _isPresented = isPresented
        _adjustedOutcome = State(initialValue: bet.sixWeekOutcome)
        _adjustedEvidenceGoal = State(initialValue: bet.evidenceGoal ?? bet.sixWeekOutcome)
        _adjustedAssumption = State(initialValue: bet.riskiestAssumption)
        _adjustedHorizonDays = State(initialValue: bet.resolvedHorizonDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("复盘“\(bet.title)”")
                    .font(.title2.weight(.bold))
                Text("回看这个周期真实发生了什么，再决定是否值得继续占用注意力。")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    reviewMetric("当期证据", "\(evidence.count)")
                    reviewMetric("外部证据", "\(externalEvidenceCount)")
                    reviewMetric("最强证据", strongestKind?.title ?? "暂无")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("原定证据门槛")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bet.evidenceGoal ?? bet.sixWeekOutcome)
                }

                TextField("本周期最重要的结论是什么？没有取得证据也要写明原因。", text: $conclusion, axis: .vertical)
                    .lineLimit(4...7)
                    .textFieldStyle(.roundedBorder)

                Picker("复盘决定", selection: $decision) {
                    ForEach(BetCycleDecision.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text(decisionDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if decision == .adjust {
                    Divider()
                    Text("定义新周期")
                        .font(.headline)
                    Picker("新周期", selection: $adjustedHorizonDays) {
                        Text("7 天验证").tag(7)
                        Text("14 天推进").tag(14)
                    }
                    .pickerStyle(.segmented)
                    TextField("新周期结果", text: $adjustedOutcome, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                    TextField("新周期证据门槛", text: $adjustedEvidenceGoal, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                    TextField("新的最危险假设", text: $adjustedAssumption, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("取消") { isPresented = false }
                    Spacer()
                    Button(confirmTitle) { saveReview() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 640, height: decision == .adjust ? 720 : 560)
    }

    private func reviewMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private var decisionDetail: String {
        switch decision {
        case .continueBet: "保留当前定义，从今天开始一个同长度的新周期。"
        case .adjust: "保存旧周期快照，修改结果、门槛或危险假设后开始新周期。"
        case .complete: "关闭押注并保留完整历史；有当前焦点时不能完成。"
        case .park: "暂时移出当前押注；有当前焦点时不能停放。"
        }
    }

    private var confirmTitle: String {
        switch decision {
        case .continueBet: "保存复盘并继续"
        case .adjust: "保存复盘并调整"
        case .complete: "保存复盘并完成"
        case .park: "保存复盘并停放"
        }
    }

    private func saveReview() {
        do {
            try store.reviewBet(
                bet.id,
                conclusion: conclusion,
                decision: decision,
                adjustedOutcome: adjustedOutcome,
                adjustedEvidenceGoal: adjustedEvidenceGoal,
                adjustedAssumption: adjustedAssumption,
                adjustedHorizonDays: adjustedHorizonDays
            )
            isPresented = false
        } catch {
            store.present(error)
        }
    }
}

struct NewBetSheet: View {
    @ObservedObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var outcome = ""
    @State private var assumption = ""
    @State private var evidenceGoal = ""
    @State private var horizonDays = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("新增一条滚动押注")
                .font(.title2.weight(.bold))
            Text("只固定周期结果。每天做什么，等实际证据回来后再决定。")
                .foregroundStyle(.secondary)

            Picker("周期", selection: $horizonDays) {
                Text("7 天验证").tag(7)
                Text("14 天推进").tag(14)
            }
            .pickerStyle(.segmented)

            TextField("押注名称，例如：让三位开发者持续使用 Better", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("周期结束时，什么真实结果会发生变化？", text: $outcome, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            TextField("达到什么证据，才算这次押注成立？", text: $evidenceGoal, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            TextField("现在最可能让这件事失败的假设是什么？", text: $assumption, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { isPresented = false }
                Spacer()
                Button("加入当前押注") {
                    do {
                        guard !evidenceGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            throw BetterStoreError.emptyField("周期证据门槛")
                        }
                        try store.addBet(
                            title: title,
                            outcome: outcome,
                            assumption: assumption,
                            horizonDays: horizonDays,
                            evidenceGoal: evidenceGoal
                        )
                        isPresented = false
                    } catch {
                        store.present(error)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600)
    }
}
