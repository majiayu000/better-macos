import SwiftUI

struct DecisionView: View {
    @ObservedObject var store: AppStore
    let onChoose: () -> Void

    @State private var betID: UUID?
    @State private var action = ""
    @State private var evidence = ""
    @State private var kind: EvidenceKind = .attempt
    @State private var validatesAssumption = true
    @State private var within48Hours = true
    @State private var oneBlock = true
    @State private var expandsScope = false
    @State private var candidates: [ActionCandidate] = []

    private var ranked: [ScoredCandidate] { DecisionEngine.rank(candidates) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "决策，而非待办",
                    title: "我不知道该做什么",
                    detail: "写下两三个可能行动。工具只比较取得证据的速度和代价，不奖励任务数量。"
                )

                if store.activeBets.isEmpty {
                    EmptyCallout(
                        symbol: "square.stack.3d.up.slash",
                        title: "还没有可推进的押注",
                        detail: "先确定 7 天或 14 天结果，再比较行动。没有方向时继续列 Todo 只会增加噪音。"
                    )
                } else {
                    CodexCoachCard(store: store, onChoose: onChoose)
                    candidateForm
                    ranking
                }
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .onAppear {
            if betID == nil { betID = store.activeBets.first?.id }
        }
    }

    private var candidateForm: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("加入一个候选行动")
                    .font(.title3.weight(.semibold))

                Picker("推进哪条押注", selection: $betID) {
                    ForEach(store.activeBets) { bet in
                        Text(bet.title).tag(Optional(bet.id))
                    }
                }

                if let betID, let bet = store.bet(id: betID) {
                    Text("要验证：\(bet.riskiestAssumption)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("具体行动", text: $action, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                TextField("行动结束后能看到的证据", text: $evidence, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Picker("证据类型", selection: $kind) {
                    ForEach(EvidenceKind.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("它会验证当前最危险的假设", isOn: $validatesAssumption)
                    Toggle("48 小时内能看到证据", isOn: $within48Hours)
                    Toggle("一个专注段内能交付", isOn: $oneBlock)
                    Toggle("它会新开项目或扩大长期维护面", isOn: $expandsScope)
                }

                HStack {
                    Spacer()
                    Button("加入比较") { addCandidate() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var ranking: some View {
        if candidates.isEmpty {
            Text("加入至少两个候选项，差异才有意义。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("建议顺序")
                    .font(.headline)
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, result in
                    BetterCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(String(index + 1))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.tint)
                                Text(result.candidate.action)
                                    .font(.headline)
                                Spacer()
                                Text("\(result.score) 分")
                                    .font(.headline.monospacedDigit())
                            }
                            Text(result.candidate.expectedEvidence)
                                .foregroundStyle(.secondary)
                            Text(result.reasons.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Spacer()
                                if index == 0 {
                                    Button("选为今天唯一行动") { choose(result.candidate) }
                                        .buttonStyle(.borderedProminent)
                                } else {
                                    Button("选为今天唯一行动") { choose(result.candidate) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func addCandidate() {
        guard let betID else {
            store.present(BetterStoreError.unknownBet)
            return
        }
        let cleanAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEvidence = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAction.isEmpty else {
            store.present(BetterStoreError.emptyField("具体行动"))
            return
        }
        guard !cleanEvidence.isEmpty else {
            store.present(BetterStoreError.emptyField("预期证据"))
            return
        }
        candidates.append(ActionCandidate(
            betID: betID,
            action: cleanAction,
            expectedEvidence: cleanEvidence,
            evidenceKind: kind,
            validatesRiskiestAssumption: validatesAssumption,
            evidenceWithin48Hours: within48Hours,
            fitsOneFocusBlock: oneBlock,
            expandsMaintenanceSurface: expandsScope
        ))
        action = ""
        evidence = ""
    }

    private func choose(_ candidate: ActionCandidate) {
        do {
            try store.createFocus(
                betID: candidate.betID,
                action: candidate.action,
                expectedEvidence: candidate.expectedEvidence,
                kind: candidate.evidenceKind,
                durationMinutes: 50
            )
            onChoose()
        } catch {
            store.present(error)
        }
    }
}
