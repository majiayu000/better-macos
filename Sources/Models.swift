import Foundation

enum EvidenceKind: String, Codable, CaseIterable, Identifiable {
    case problem
    case attempt
    case returnUse
    case commitment
    case payment
    case deliverable
    case reproducibleLearning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .problem: "问题证据"
        case .attempt: "真实尝试"
        case .returnUse: "主动返回"
        case .commitment: "投入承诺"
        case .payment: "付费证据"
        case .deliverable: "可交付产物"
        case .reproducibleLearning: "可复现理解"
        }
    }

    var detail: String {
        switch self {
        case .problem: "具体的人描述了问题和现有替代方案"
        case .attempt: "真实的人愿意试用或让你手工代办一次"
        case .returnUse: "对方没有被催促，仍再次使用或追问"
        case .commitment: "对方投入时间、数据、安装成本或关系"
        case .payment: "对方愿意为结果付费"
        case .deliverable: "工作任务形成可验收、可交付的产物"
        case .reproducibleLearning: "能独立复现、解释或测量一个机制"
        }
    }

    var strength: Int {
        switch self {
        case .problem: 1
        case .attempt: 2
        case .returnUse: 3
        case .commitment: 4
        case .payment: 5
        case .deliverable: 2
        case .reproducibleLearning: 1
        }
    }

    var isExternal: Bool {
        switch self {
        case .problem, .attempt, .returnUse, .commitment, .payment: true
        case .deliverable, .reproducibleLearning: false
        }
    }
}

enum BetStatus: String, Codable {
    case active
    case parked
    case completed
}

struct Bet: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var sixWeekOutcome: String
    var riskiestAssumption: String
    var status: BetStatus
    var createdAt: Date
    var horizonDays: Int?
    var evidenceGoal: String?
    var cycleStartedAt: Date?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        sixWeekOutcome: String,
        riskiestAssumption: String,
        status: BetStatus = .active,
        createdAt: Date = .now,
        horizonDays: Int = 14,
        evidenceGoal: String = "",
        cycleStartedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.sixWeekOutcome = sixWeekOutcome
        self.riskiestAssumption = riskiestAssumption
        self.status = status
        self.createdAt = createdAt
        self.horizonDays = horizonDays
        self.evidenceGoal = evidenceGoal
        self.cycleStartedAt = cycleStartedAt
        self.completedAt = completedAt
    }

    var resolvedHorizonDays: Int { horizonDays == 7 ? 7 : 14 }
    var cycleStartDate: Date { cycleStartedAt ?? createdAt }

    var reviewDate: Date {
        Calendar.current.date(byAdding: .day, value: resolvedHorizonDays, to: cycleStartDate) ?? cycleStartDate
    }

    func isReviewDue(at date: Date = .now) -> Bool {
        reviewDate <= date
    }
}

enum BetCycleDecision: String, Codable, CaseIterable, Identifiable {
    case continueBet
    case adjust
    case complete
    case park

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continueBet: "继续"
        case .adjust: "调整"
        case .complete: "完成"
        case .park: "停放"
        }
    }
}

struct BetCycleReview: Codable, Equatable, Identifiable {
    var id: UUID
    var betID: UUID
    var betTitle: String
    var cycleStartedAt: Date
    var reviewedAt: Date
    var horizonDays: Int
    var outcome: String
    var evidenceGoal: String
    var riskiestAssumption: String
    var evidenceCount: Int
    var externalEvidenceCount: Int
    var strongestEvidenceKind: EvidenceKind?
    var conclusion: String
    var decision: BetCycleDecision

    init(
        id: UUID = UUID(),
        betID: UUID,
        betTitle: String,
        cycleStartedAt: Date,
        reviewedAt: Date = .now,
        horizonDays: Int,
        outcome: String,
        evidenceGoal: String,
        riskiestAssumption: String,
        evidenceCount: Int,
        externalEvidenceCount: Int,
        strongestEvidenceKind: EvidenceKind?,
        conclusion: String,
        decision: BetCycleDecision
    ) {
        self.id = id
        self.betID = betID
        self.betTitle = betTitle
        self.cycleStartedAt = cycleStartedAt
        self.reviewedAt = reviewedAt
        self.horizonDays = horizonDays
        self.outcome = outcome
        self.evidenceGoal = evidenceGoal
        self.riskiestAssumption = riskiestAssumption
        self.evidenceCount = evidenceCount
        self.externalEvidenceCount = externalEvidenceCount
        self.strongestEvidenceKind = strongestEvidenceKind
        self.conclusion = conclusion
        self.decision = decision
    }
}

struct FocusPlan: Codable, Equatable, Identifiable {
    var id: UUID
    var betID: UUID
    var action: String
    var expectedEvidence: String
    var evidenceKind: EvidenceKind
    var durationMinutes: Int
    var createdAt: Date
    var startedAt: Date?
    var endsAt: Date?

    init(
        id: UUID = UUID(),
        betID: UUID,
        action: String,
        expectedEvidence: String,
        evidenceKind: EvidenceKind,
        durationMinutes: Int,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        endsAt: Date? = nil
    ) {
        self.id = id
        self.betID = betID
        self.action = action
        self.expectedEvidence = expectedEvidence
        self.evidenceKind = evidenceKind
        self.durationMinutes = durationMinutes
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    var isRunning: Bool { startedAt != nil }
}

struct EvidenceRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var betID: UUID
    var action: String
    var expectedEvidence: String
    var actualEvidence: String
    var unresolvedQuestion: String
    var kind: EvidenceKind
    var recordedAt: Date
    var focusMinutes: Int
    var adaptationNote: String?
    var energyLevel: Int?

    init(
        id: UUID = UUID(),
        betID: UUID,
        action: String,
        expectedEvidence: String,
        actualEvidence: String,
        unresolvedQuestion: String,
        kind: EvidenceKind,
        recordedAt: Date = .now,
        focusMinutes: Int,
        adaptationNote: String = "",
        energyLevel: Int? = nil
    ) {
        self.id = id
        self.betID = betID
        self.action = action
        self.expectedEvidence = expectedEvidence
        self.actualEvidence = actualEvidence
        self.unresolvedQuestion = unresolvedQuestion
        self.kind = kind
        self.recordedAt = recordedAt
        self.focusMinutes = focusMinutes
        self.adaptationNote = adaptationNote
        self.energyLevel = energyLevel
    }
}

struct ParkedIdea: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var note: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, note: String = "", createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
    }
}

struct ReminderSettings: Codable, Equatable {
    var enabled = false
    var startHour = 9
    var startMinute = 30
    var reviewHour = 21
    var reviewMinute = 30
}

enum CoachMessageRole: String, Codable {
    case user
    case assistant
}

struct CoachMessage: Codable, Equatable, Identifiable {
    var id: UUID
    var role: CoachMessageRole
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct CoachThreadArchive: Codable, Equatable, Identifiable {
    var id: UUID
    var threadID: String
    var archivedAt: Date
    var reason: String
    var handoffSummary: String
    var messageCount: Int

    init(
        id: UUID = UUID(),
        threadID: String,
        archivedAt: Date = .now,
        reason: String,
        handoffSummary: String,
        messageCount: Int
    ) {
        self.id = id
        self.threadID = threadID
        self.archivedAt = archivedAt
        self.reason = reason
        self.handoffSummary = handoffSummary
        self.messageCount = messageCount
    }
}

struct CoachState: Codable, Equatable {
    var threadID: String?
    var createdAt: Date?
    var lastUsedAt: Date?
    var lastContextFingerprint: String?
    var messages: [CoachMessage]
    var pendingSuggestion: CodexFocusSuggestion?
    var rebuiltAt: Date?
    var archivedThreads: [CoachThreadArchive]?

    init(
        threadID: String? = nil,
        createdAt: Date? = nil,
        lastUsedAt: Date? = nil,
        lastContextFingerprint: String? = nil,
        messages: [CoachMessage] = [],
        pendingSuggestion: CodexFocusSuggestion? = nil,
        rebuiltAt: Date? = nil,
        archivedThreads: [CoachThreadArchive]? = nil
    ) {
        self.threadID = threadID
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.lastContextFingerprint = lastContextFingerprint
        self.messages = messages
        self.pendingSuggestion = pendingSuggestion
        self.rebuiltAt = rebuiltAt
        self.archivedThreads = archivedThreads
    }
}

struct GitCommitSnapshot: Codable, Equatable, Identifiable {
    var id: String { fullSHA }
    var fullSHA: String
    var shortSHA: String
    var committedAt: Date
    var subject: String
}

struct GitRepositorySnapshot: Codable, Equatable {
    var capturedAt: Date
    var rootPath: String
    var branch: String
    var headSHA: String
    var upstream: String?
    var aheadCount: Int?
    var behindCount: Int?
    var stagedCount: Int
    var modifiedCount: Int
    var untrackedCount: Int
    var conflictCount: Int
    var recentCommits: [GitCommitSnapshot]

    var shortHeadSHA: String { String(headSHA.prefix(8)) }
    var hasWorkingTreeChanges: Bool {
        stagedCount + modifiedCount + untrackedCount + conflictCount > 0
    }
}

struct GitRepositoryWatch: Codable, Equatable, Identifiable {
    var id: UUID
    var rootPath: String
    var displayName: String
    var addedAt: Date
    var enabled: Bool
    var lastRefreshAttemptAt: Date?
    var lastSnapshot: GitRepositorySnapshot?
    var lastError: String?

    init(
        id: UUID = UUID(),
        rootPath: String,
        displayName: String,
        addedAt: Date = .now,
        enabled: Bool = true,
        lastRefreshAttemptAt: Date? = nil,
        lastSnapshot: GitRepositorySnapshot? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.rootPath = rootPath
        self.displayName = displayName
        self.addedAt = addedAt
        self.enabled = enabled
        self.lastRefreshAttemptAt = lastRefreshAttemptAt
        self.lastSnapshot = lastSnapshot
        self.lastError = lastError
    }
}

struct BetterData: Codable, Equatable {
    static let currentVersion = 4

    var version: Int
    var bets: [Bet] = []
    var currentFocus: FocusPlan?
    var evidence: [EvidenceRecord] = []
    var parkedIdeas: [ParkedIdea] = []
    var reminders = ReminderSettings()
    var coach = CoachState()
    var pendingReviewEvidenceID: UUID?
    var cycleReviews: [BetCycleReview]
    var gitRepositories: [GitRepositoryWatch]

    init(
        version: Int = BetterData.currentVersion,
        bets: [Bet] = [],
        currentFocus: FocusPlan? = nil,
        evidence: [EvidenceRecord] = [],
        parkedIdeas: [ParkedIdea] = [],
        reminders: ReminderSettings = ReminderSettings(),
        coach: CoachState = CoachState(),
        pendingReviewEvidenceID: UUID? = nil,
        cycleReviews: [BetCycleReview] = [],
        gitRepositories: [GitRepositoryWatch] = []
    ) {
        self.version = version
        self.bets = bets
        self.currentFocus = currentFocus
        self.evidence = evidence
        self.parkedIdeas = parkedIdeas
        self.reminders = reminders
        self.coach = coach
        self.pendingReviewEvidenceID = pendingReviewEvidenceID
        self.cycleReviews = cycleReviews
        self.gitRepositories = gitRepositories
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case bets
        case currentFocus
        case evidence
        case parkedIdeas
        case reminders
        case coach
        case pendingReviewEvidenceID
        case cycleReviews
        case gitRepositories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = BetterData.currentVersion
        bets = try container.decodeIfPresent([Bet].self, forKey: .bets) ?? []
        currentFocus = try container.decodeIfPresent(FocusPlan.self, forKey: .currentFocus)
        evidence = try container.decodeIfPresent([EvidenceRecord].self, forKey: .evidence) ?? []
        parkedIdeas = try container.decodeIfPresent([ParkedIdea].self, forKey: .parkedIdeas) ?? []
        reminders = try container.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? ReminderSettings()
        coach = try container.decodeIfPresent(CoachState.self, forKey: .coach) ?? CoachState()
        pendingReviewEvidenceID = try container.decodeIfPresent(UUID.self, forKey: .pendingReviewEvidenceID)
        cycleReviews = try container.decodeIfPresent([BetCycleReview].self, forKey: .cycleReviews) ?? []
        gitRepositories = try container.decodeIfPresent([GitRepositoryWatch].self, forKey: .gitRepositories) ?? []
    }
}

struct ActionCandidate: Equatable, Identifiable {
    var id = UUID()
    var betID: UUID
    var action: String
    var expectedEvidence: String
    var evidenceKind: EvidenceKind
    var validatesRiskiestAssumption: Bool
    var evidenceWithin48Hours: Bool
    var fitsOneFocusBlock: Bool
    var expandsMaintenanceSurface: Bool
}

struct ScoredCandidate: Equatable, Identifiable {
    var id: UUID { candidate.id }
    let candidate: ActionCandidate
    let score: Int
    let reasons: [String]
}

struct CodexFocusSuggestion: Codable, Equatable, Identifiable {
    var id = UUID()
    var betID: UUID
    var action: String
    var expectedEvidence: String
    var evidenceKind: EvidenceKind
    var durationMinutes: Int
    var rationale: String

    enum CodingKeys: String, CodingKey {
        case betID = "bet_id"
        case action
        case expectedEvidence = "expected_evidence"
        case evidenceKind = "evidence_kind"
        case durationMinutes = "duration_minutes"
        case rationale
    }
}
