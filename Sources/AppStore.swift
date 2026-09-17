import Combine
import Foundation

enum BetterStoreError: LocalizedError, Equatable {
    case activeBetLimit
    case emptyField(String)
    case unknownBet
    case focusAlreadyExists
    case noFocus
    case focusAlreadyStarted
    case focusNotStarted
    case noCoachSuggestion
    case cannotCloseFocusedBet
    case reviewRequiredBeforeHorizonChange
    case gitRepositoryLimit
    case gitRepositoryAlreadyWatched
    case unknownGitRepository

    var errorDescription: String? {
        switch self {
        case .activeBetLimit:
            "当前押注最多三条。请先完成或停放一条。"
        case let .emptyField(name):
            "请填写\(name)。"
        case .unknownBet:
            "找不到这条押注，它可能已经被停放或删除。"
        case .focusAlreadyExists:
            "今天已经有一件焦点。请先完成它，再选择下一件。"
        case .noFocus:
            "当前没有焦点行动。"
        case .focusAlreadyStarted:
            "这段专注已经开始。"
        case .focusNotStarted:
            "请先开始专注，再记录结果。"
        case .noCoachSuggestion:
            "当前没有可确认的 Better Coach 提案。"
        case .cannotCloseFocusedBet:
            "这条押注仍有当前焦点。请先完成或重新选择焦点，再关闭押注。"
        case .reviewRequiredBeforeHorizonChange:
            "这条押注已经到复盘日。请在周期复盘中调整下一周期长度。"
        case .gitRepositoryLimit:
            "最多关注 8 个 Git 仓库。请先移除不再需要的上下文。"
        case .gitRepositoryAlreadyWatched:
            "这个 Git 仓库已经在 Better 的关注列表中。"
        case .unknownGitRepository:
            "找不到这条 Git 仓库关注记录。"
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: BetterData
    @Published var errorMessage: String?

    let storageURL: URL
    private let reminders: ReminderScheduling

    init(storageURL: URL? = nil, reminders: ReminderScheduling = ReminderService.shared) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        self.reminders = reminders

        do {
            data = try Self.load(from: self.storageURL)
        } catch {
            data = BetterData()
            errorMessage = "无法读取本地数据：\(error.localizedDescription)。原文件未被覆盖。"
        }
    }

    var activeBets: [Bet] {
        data.bets
            .filter { $0.status == .active }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var parkedBets: [Bet] {
        data.bets.filter { $0.status == .parked }
    }

    var completedBets: [Bet] {
        data.bets
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var enabledGitRepositories: [GitRepositoryWatch] {
        data.gitRepositories.filter(\.enabled)
    }

    func bet(id: UUID) -> Bet? {
        data.bets.first { $0.id == id }
    }

    func addBet(
        title: String,
        outcome: String,
        assumption: String,
        horizonDays: Int = 14,
        evidenceGoal: String = ""
    ) throws {
        guard activeBets.count < 3 else { throw BetterStoreError.activeBetLimit }
        let cleanTitle = try required(title, name: "押注名称")
        let cleanOutcome = try required(outcome, name: "周期结果")
        let cleanAssumption = try required(assumption, name: "最危险的假设")
        let requestedEvidenceGoal = evidenceGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEvidenceGoal = requestedEvidenceGoal.isEmpty ? cleanOutcome : requestedEvidenceGoal
        try update { data in
            data.bets.append(Bet(
                title: cleanTitle,
                sixWeekOutcome: cleanOutcome,
                riskiestAssumption: cleanAssumption,
                horizonDays: horizonDays == 7 ? 7 : 14,
                evidenceGoal: cleanEvidenceGoal
            ))
        }
    }

    func updateBet(
        _ id: UUID,
        title: String,
        outcome: String,
        assumption: String,
        horizonDays: Int,
        evidenceGoal: String
    ) throws {
        let cleanTitle = try required(title, name: "押注名称")
        let cleanOutcome = try required(outcome, name: "周期结果")
        let cleanAssumption = try required(assumption, name: "最危险的假设")
        let cleanEvidenceGoal = try required(evidenceGoal, name: "周期证据门槛")
        let normalizedHorizonDays = horizonDays == 7 ? 7 : 14
        try update { data in
            guard let index = data.bets.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownBet
            }
            if data.bets[index].isReviewDue(),
               data.bets[index].resolvedHorizonDays != normalizedHorizonDays {
                throw BetterStoreError.reviewRequiredBeforeHorizonChange
            }
            data.bets[index].title = cleanTitle
            data.bets[index].sixWeekOutcome = cleanOutcome
            data.bets[index].riskiestAssumption = cleanAssumption
            data.bets[index].horizonDays = normalizedHorizonDays
            data.bets[index].evidenceGoal = cleanEvidenceGoal
        }
    }

    func parkBet(_ id: UUID) throws {
        try update { data in
            guard let index = data.bets.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownBet
            }
            if data.currentFocus?.betID == id {
                throw BetterStoreError.focusAlreadyExists
            }
            data.bets[index].status = .parked
        }
    }

    func reactivateBet(_ id: UUID) throws {
        guard activeBets.count < 3 else { throw BetterStoreError.activeBetLimit }
        try update { data in
            guard let index = data.bets.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownBet
            }
            data.bets[index].status = .active
            data.bets[index].cycleStartedAt = .now
            data.bets[index].completedAt = nil
        }
    }

    func completeBet(_ id: UUID) throws {
        try update { data in
            guard let index = data.bets.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownBet
            }
            if data.currentFocus?.betID == id {
                throw BetterStoreError.focusAlreadyExists
            }
            data.bets[index].status = .completed
            data.bets[index].completedAt = .now
        }
    }

    func cycleEvidence(for betID: UUID, through now: Date = .now) -> [EvidenceRecord] {
        guard let bet = bet(id: betID) else { return [] }
        return data.evidence.filter {
            $0.betID == betID && $0.recordedAt >= bet.cycleStartDate && $0.recordedAt <= now
        }
    }

    func reviews(for betID: UUID) -> [BetCycleReview] {
        data.cycleReviews.filter { $0.betID == betID }
    }

    func addGitRepository(snapshot: GitRepositorySnapshot, now: Date = .now) throws {
        guard data.gitRepositories.count < 8 else { throw BetterStoreError.gitRepositoryLimit }
        let rootPath = snapshot.rootPath
        guard !data.gitRepositories.contains(where: { $0.rootPath == rootPath }) else {
            throw BetterStoreError.gitRepositoryAlreadyWatched
        }
        let displayName = URL(fileURLWithPath: rootPath).lastPathComponent
        try update { data in
            data.gitRepositories.append(
                GitRepositoryWatch(
                    rootPath: rootPath,
                    displayName: displayName,
                    addedAt: now,
                    enabled: true,
                    lastRefreshAttemptAt: snapshot.capturedAt,
                    lastSnapshot: snapshot,
                    lastError: nil
                )
            )
        }
    }

    func setGitRepositoryEnabled(_ id: UUID, enabled: Bool) throws {
        try update { data in
            guard let index = data.gitRepositories.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownGitRepository
            }
            data.gitRepositories[index].enabled = enabled
        }
    }

    func removeGitRepository(_ id: UUID) throws {
        try update { data in
            guard data.gitRepositories.contains(where: { $0.id == id }) else {
                throw BetterStoreError.unknownGitRepository
            }
            data.gitRepositories.removeAll { $0.id == id }
        }
    }

    func applyGitRefreshes(_ refreshes: [GitRefreshUpdate]) throws {
        guard !refreshes.isEmpty else { return }
        try update { data in
            for refresh in refreshes {
                guard let index = data.gitRepositories.firstIndex(where: {
                    $0.id == refresh.repositoryID
                }) else {
                    throw BetterStoreError.unknownGitRepository
                }
                data.gitRepositories[index].lastRefreshAttemptAt = refresh.attemptedAt
                if let snapshot = refresh.snapshot {
                    data.gitRepositories[index].rootPath = snapshot.rootPath
                    data.gitRepositories[index].lastSnapshot = snapshot
                    data.gitRepositories[index].lastError = nil
                } else {
                    data.gitRepositories[index].lastError = refresh.errorMessage
                        ?? "Git 刷新失败，但没有返回具体原因。"
                }
            }
        }
    }

    func reviewBet(
        _ id: UUID,
        conclusion: String,
        decision: BetCycleDecision,
        adjustedOutcome: String = "",
        adjustedEvidenceGoal: String = "",
        adjustedAssumption: String = "",
        adjustedHorizonDays: Int = 14,
        now: Date = .now
    ) throws {
        let cleanConclusion = try required(conclusion, name: "本周期结论")
        let adjustedFields: (outcome: String, evidenceGoal: String, assumption: String)?
        if decision == .adjust {
            adjustedFields = (
                try required(adjustedOutcome, name: "新周期结果"),
                try required(adjustedEvidenceGoal, name: "新周期证据门槛"),
                try required(adjustedAssumption, name: "新周期最危险的假设")
            )
        } else {
            adjustedFields = nil
        }

        try update { data in
            guard let index = data.bets.firstIndex(where: { $0.id == id }) else {
                throw BetterStoreError.unknownBet
            }
            let previousBet = data.bets[index]
            if [.complete, .park].contains(decision), data.currentFocus?.betID == id {
                throw BetterStoreError.cannotCloseFocusedBet
            }

            let cycleEvidence = data.evidence.filter {
                $0.betID == id &&
                $0.recordedAt >= previousBet.cycleStartDate &&
                $0.recordedAt <= now
            }
            let strongestKind = cycleEvidence.max {
                $0.kind.strength < $1.kind.strength
            }?.kind
            let review = BetCycleReview(
                betID: previousBet.id,
                betTitle: previousBet.title,
                cycleStartedAt: previousBet.cycleStartDate,
                reviewedAt: now,
                horizonDays: previousBet.resolvedHorizonDays,
                outcome: previousBet.sixWeekOutcome,
                evidenceGoal: previousBet.evidenceGoal ?? previousBet.sixWeekOutcome,
                riskiestAssumption: previousBet.riskiestAssumption,
                evidenceCount: cycleEvidence.count,
                externalEvidenceCount: cycleEvidence.filter { $0.kind.isExternal }.count,
                strongestEvidenceKind: strongestKind,
                conclusion: cleanConclusion,
                decision: decision
            )

            switch decision {
            case .continueBet:
                data.bets[index].cycleStartedAt = now
                data.bets[index].completedAt = nil
            case .adjust:
                guard let adjustedFields else {
                    throw BetterStoreError.emptyField("新周期定义")
                }
                data.bets[index].sixWeekOutcome = adjustedFields.outcome
                data.bets[index].evidenceGoal = adjustedFields.evidenceGoal
                data.bets[index].riskiestAssumption = adjustedFields.assumption
                data.bets[index].horizonDays = adjustedHorizonDays == 7 ? 7 : 14
                data.bets[index].cycleStartedAt = now
                data.bets[index].completedAt = nil
            case .complete:
                data.bets[index].status = .completed
                data.bets[index].completedAt = now
            case .park:
                data.bets[index].status = .parked
                data.bets[index].completedAt = nil
            }

            data.cycleReviews.insert(review, at: 0)
            Self.rotateCoachThread(in: &data, review: review, updatedBet: data.bets[index], now: now)
        }
    }

    func createFocus(
        betID: UUID,
        action: String,
        expectedEvidence: String,
        kind: EvidenceKind,
        durationMinutes: Int
    ) throws {
        guard data.currentFocus == nil else { throw BetterStoreError.focusAlreadyExists }
        guard activeBets.contains(where: { $0.id == betID }) else { throw BetterStoreError.unknownBet }
        let cleanAction = try required(action, name: "唯一行动")
        let cleanEvidence = try required(expectedEvidence, name: "预期证据")
        try update { data in
            data.currentFocus = FocusPlan(
                betID: betID,
                action: cleanAction,
                expectedEvidence: cleanEvidence,
                evidenceKind: kind,
                durationMinutes: [25, 50, 90].contains(durationMinutes) ? durationMinutes : 50
            )
        }
    }

    func startFocus(now: Date = .now) throws {
        guard var focus = data.currentFocus else { throw BetterStoreError.noFocus }
        guard !focus.isRunning else { throw BetterStoreError.focusAlreadyStarted }
        focus.startedAt = now
        focus.endsAt = Calendar.current.date(byAdding: .minute, value: focus.durationMinutes, to: now)
        try update { $0.currentFocus = focus }

        if let end = focus.endsAt {
            Task {
                do {
                    try await reminders.scheduleFocusEnd(at: end, action: focus.action)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func discardUnstartedFocus() throws {
        guard let focus = data.currentFocus else { throw BetterStoreError.noFocus }
        guard !focus.isRunning else { throw BetterStoreError.focusAlreadyStarted }
        try update { $0.currentFocus = nil }
    }

    func completeFocus(
        actualEvidence: String,
        unresolvedQuestion: String,
        adaptationNote: String = "",
        energyLevel: Int? = nil
    ) throws {
        guard let focus = data.currentFocus else { throw BetterStoreError.noFocus }
        guard focus.isRunning else { throw BetterStoreError.focusNotStarted }
        let cleanEvidence = try required(actualEvidence, name: "实际证据；如果没有，请写明原因")
        let cleanUnknown = unresolvedQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = EvidenceRecord(
            betID: focus.betID,
            action: focus.action,
            expectedEvidence: focus.expectedEvidence,
            actualEvidence: cleanEvidence,
            unresolvedQuestion: cleanUnknown,
            kind: focus.evidenceKind,
            focusMinutes: focus.durationMinutes,
            adaptationNote: adaptationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            energyLevel: energyLevel.map { min(max($0, 1), 5) }
        )
        try update { data in
            data.evidence.insert(record, at: 0)
            data.currentFocus = nil
            data.pendingReviewEvidenceID = record.id
        }
        reminders.cancelFocusEnd()
    }

    func addParkedIdea(title: String, note: String) throws {
        let cleanTitle = try required(title, name: "想法")
        try update { data in
            data.parkedIdeas.insert(ParkedIdea(title: cleanTitle, note: note.trimmingCharacters(in: .whitespacesAndNewlines)), at: 0)
        }
    }

    func removeParkedIdea(_ id: UUID) throws {
        try update { data in
            data.parkedIdeas.removeAll { $0.id == id }
        }
    }

    func updateReminders(_ settings: ReminderSettings) throws {
        try update { $0.reminders = settings }
        Task {
            do {
                try await reminders.applyDaily(settings)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func acceptCodexSuggestion(_ suggestion: CodexFocusSuggestion) throws {
        try createFocus(
            betID: suggestion.betID,
            action: suggestion.action,
            expectedEvidence: suggestion.expectedEvidence,
            kind: suggestion.evidenceKind,
            durationMinutes: suggestion.durationMinutes
        )
    }

    func recordCoachExchange(
        userText: String,
        assistantText: String,
        threadID: String,
        contextFingerprint: String,
        rebuiltThread: Bool,
        now: Date = .now
    ) throws {
        let fields = try coachExchangeFields(
            userText: userText,
            assistantText: assistantText,
            threadID: threadID
        )
        try update { data in
            Self.applyCoachExchange(
                to: &data,
                fields: fields,
                contextFingerprint: contextFingerprint,
                rebuiltThread: rebuiltThread,
                now: now
            )
        }
    }

    func recordCoachSuggestion(
        _ suggestion: CodexFocusSuggestion,
        userText: String,
        assistantText: String,
        threadID: String,
        contextFingerprint: String,
        rebuiltThread: Bool,
        now: Date = .now
    ) throws {
        try CodexPlanningService.validate(suggestion, against: data)
        let fields = try coachExchangeFields(
            userText: userText,
            assistantText: assistantText,
            threadID: threadID
        )
        try update { data in
            Self.applyCoachExchange(
                to: &data,
                fields: fields,
                contextFingerprint: contextFingerprint,
                rebuiltThread: rebuiltThread,
                now: now
            )
            data.coach.pendingSuggestion = suggestion
        }
    }

    func clearCoachSuggestion() throws {
        try update { $0.coach.pendingSuggestion = nil }
    }

    func acceptCoachSuggestion() throws {
        guard let suggestion = data.coach.pendingSuggestion else {
            throw BetterStoreError.noCoachSuggestion
        }
        try CodexPlanningService.validate(suggestion, against: data)
        guard data.currentFocus == nil else { throw BetterStoreError.focusAlreadyExists }
        try update { data in
            data.currentFocus = FocusPlan(
                betID: suggestion.betID,
                action: suggestion.action,
                expectedEvidence: suggestion.expectedEvidence,
                evidenceKind: suggestion.evidenceKind,
                durationMinutes: suggestion.durationMinutes
            )
            data.coach.pendingSuggestion = nil
        }
    }

    func rescheduleReminders() {
        let settings = data.reminders
        Task {
            do {
                try await reminders.applyDaily(settings)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func reloadFromDisk() {
        do {
            let loaded = try Self.load(from: storageURL)
            if loaded != data {
                data = loaded
            }
        } catch {
            errorMessage = "无法重新读取 Better 数据：\(error.localizedDescription)。当前内存数据未被覆盖。"
        }
    }

    private func required(_ value: String, name: String) throws -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw BetterStoreError.emptyField(name) }
        return clean
    }

    private func coachExchangeFields(
        userText: String,
        assistantText: String,
        threadID: String
    ) throws -> (userText: String, assistantText: String, threadID: String) {
        (
            try required(userText, name: "发给 Better Coach 的消息"),
            try required(assistantText, name: "Better Coach 回复"),
            try required(threadID, name: "Codex 线程 ID")
        )
    }

    private static func applyCoachExchange(
        to data: inout BetterData,
        fields: (userText: String, assistantText: String, threadID: String),
        contextFingerprint: String,
        rebuiltThread: Bool,
        now: Date
    ) {
        data.coach.threadID = fields.threadID
        data.coach.createdAt = data.coach.createdAt ?? now
        data.coach.lastUsedAt = now
        data.coach.lastContextFingerprint = contextFingerprint
        data.coach.messages.append(
            CoachMessage(role: .user, text: fields.userText, createdAt: now)
        )
        data.coach.messages.append(
            CoachMessage(role: .assistant, text: fields.assistantText, createdAt: now)
        )
        data.coach.messages = Array(data.coach.messages.suffix(40))
        if rebuiltThread {
            data.coach.rebuiltAt = now
        }
        data.pendingReviewEvidenceID = nil
    }

    private static func rotateCoachThread(
        in data: inout BetterData,
        review: BetCycleReview,
        updatedBet: Bet,
        now: Date
    ) {
        let nextState: String
        switch review.decision {
        case .continueBet:
            nextState = "保持原押注并开启新的 \(updatedBet.resolvedHorizonDays) 天周期。"
        case .adjust:
            nextState = "调整为“\(updatedBet.sixWeekOutcome)”，并开启新的 \(updatedBet.resolvedHorizonDays) 天周期。"
        case .complete:
            nextState = "这条押注已完成。"
        case .park:
            nextState = "这条押注已停放。"
        }
        let summary = """
        押注“\(review.betTitle)”完成了一次 \(review.horizonDays) 天周期复盘。
        当期结论：\(review.conclusion)
        当期证据：\(review.evidenceCount) 条，其中外部证据 \(review.externalEvidenceCount) 条。
        决定：\(nextState)
        """

        if let threadID = data.coach.threadID {
            var archives = data.coach.archivedThreads ?? []
            archives.insert(
                CoachThreadArchive(
                    threadID: threadID,
                    archivedAt: now,
                    reason: "周期复盘：\(review.betTitle)",
                    handoffSummary: summary,
                    messageCount: data.coach.messages.count
                ),
                at: 0
            )
            data.coach.archivedThreads = Array(archives.prefix(12))
        }

        data.coach.threadID = nil
        data.coach.createdAt = nil
        data.coach.lastUsedAt = nil
        data.coach.lastContextFingerprint = nil
        data.coach.pendingSuggestion = nil
        data.coach.rebuiltAt = nil
    }

    private func update(_ mutation: (inout BetterData) throws -> Void) throws {
        var updated = data
        try mutation(&updated)
        try Self.persist(updated, to: storageURL)
        data = updated
    }

    private static func defaultStorageURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Better", isDirectory: true)
            .appendingPathComponent("better.json")
    }

    private static func load(from url: URL) throws -> BetterData {
        guard FileManager.default.fileExists(atPath: url.path) else { return BetterData() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BetterData.self, from: Data(contentsOf: url))
    }

    private static func persist(_ data: BetterData, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
    }
}
