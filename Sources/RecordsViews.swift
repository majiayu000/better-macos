import SwiftUI

struct ParkingLotView: View {
    @ObservedObject var store: AppStore
    @State private var title = ""
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "不丢掉，也不现在做",
                    title: "停车场",
                    detail: "把新想法放在这里，避免它们自动升级成项目。每周再决定是否删除。"
                )

                BetterCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("快速放下一个想法", text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextField("为什么现在不做，可选", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            Button("放进停车场") {
                                do {
                                    try store.addParkedIdea(title: title, note: note)
                                    title = ""
                                    note = ""
                                } catch {
                                    store.present(error)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if store.data.parkedIdeas.isEmpty {
                    Text("停车场是空的。新想法出现时先放这里，不要立刻开工。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.data.parkedIdeas) { idea in
                        BetterCard {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(idea.title).font(.headline)
                                    if !idea.note.isEmpty {
                                        Text(idea.note).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    do { try store.removeParkedIdea(idea.id) }
                                    catch { store.present(error) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("删除")
                            }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct EvidenceView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "衡量改变，不衡量忙碌",
                    title: "证据账本",
                    detail: "代码量、报告数和完成任务数不会自动成为价值。这里记录真实发生的变化。"
                )

                EvidenceLadder(compact: false)

                if store.data.evidence.isEmpty {
                    EmptyCallout(
                        symbol: "doc.text.magnifyingglass",
                        title: "还没有证据记录",
                        detail: "完成第一段专注后，无论成功还是失败，都留下实际结果。"
                    )
                } else {
                    HStack(spacing: 12) {
                        MetricCard(title: "记录", value: "\(store.data.evidence.count)")
                        MetricCard(title: "外部证据", value: "\(store.data.evidence.filter { $0.kind.isExternal }.count)")
                        MetricCard(title: "主动返回或更强", value: "\(store.data.evidence.filter { $0.kind.strength >= 3 && $0.kind.isExternal }.count)")
                    }

                    Text("最近记录")
                        .font(.headline)
                    ForEach(store.data.evidence) { record in
                        BetterCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(record.kind.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tint)
                                    Spacer()
                                    Text(record.recordedAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(record.action).font(.headline)
                                Text(record.actualEvidence)
                                if !record.unresolvedQuestion.isEmpty {
                                    Text("仍未知：\(record.unresolvedQuestion)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                if let note = record.adaptationNote, !note.isEmpty {
                                    Text("影响下一天：\(note)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                if let energy = record.energyLevel {
                                    Text("当日可用精力：\(energy)/5")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EvidenceLadder: View {
    let compact: Bool

    private let externalKinds: [EvidenceKind] = [.problem, .attempt, .returnUse, .commitment, .payment]

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("没有客户时的证据阶梯")
                        .font(.headline)
                    Spacer()
                    Text("弱 → 强")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if compact {
                    HStack(spacing: 6) {
                        ForEach(Array(externalKinds.enumerated()), id: \.element.id) { index, kind in
                            Text("\(index + 1) \(kind.title)")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor.opacity(0.06 + Double(index) * 0.035), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    ForEach(Array(externalKinds.enumerated()), id: \.element.id) { index, kind in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(.headline)
                                Text(kind.detail).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text("第一位客户之前，优先记录访谈完成数、真实尝试人数、七天内主动返回人数和承诺数。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
