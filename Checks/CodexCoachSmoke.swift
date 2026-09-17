import Foundation

enum CoachSmokeFailure: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(message): message
        }
    }
}

@main
struct CodexCoachSmoke {
    @MainActor
    static func main() async throws {
        let bet = Bet(
            title: "验证 Better Coach 连续会话",
            sixWeekOutcome: "确认新建和恢复使用同一个 Codex 线程",
            riskiestAssumption: "本机 CLI 能稳定恢复非交互会话",
            horizonDays: 7,
            evidenceGoal: "连续两次回复使用同一个线程 ID"
        )
        var data = BetterData(bets: [bet])
        let service = CodexCoachService()

        guard let first = await service.send(
            message: "这是隔离的连接检查。请只用一句中文确认已经建立 Better Coach 测试线程。",
            from: data
        ) else {
            throw CoachSmokeFailure.failed(service.errorMessage ?? "首次 Coach 调用没有结果")
        }

        data.coach.threadID = first.threadID
        data.coach.createdAt = .now
        data.coach.lastUsedAt = .now
        data.coach.lastContextFingerprint = first.contextFingerprint
        data.coach.messages = [
            CoachMessage(role: .user, text: "建立测试线程"),
            CoachMessage(role: .assistant, text: first.assistantText)
        ]

        guard let second = await service.send(
            message: "这是恢复检查。请只用一句中文确认已经恢复同一个线程。",
            from: data
        ) else {
            throw CoachSmokeFailure.failed(service.errorMessage ?? "恢复 Coach 调用没有结果")
        }
        guard first.threadID == second.threadID else {
            throw CoachSmokeFailure.failed("恢复后线程 ID 发生变化")
        }
        guard !first.assistantText.isEmpty, !second.assistantText.isEmpty else {
            throw CoachSmokeFailure.failed("Coach 回复为空")
        }

        print("PASS: Better Coach created and resumed thread \(first.threadID)")
    }
}
