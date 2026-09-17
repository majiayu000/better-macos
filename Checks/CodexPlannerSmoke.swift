import Foundation

enum SmokeFailure: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(message): message
        }
    }
}

@main
struct CodexPlannerSmoke {
    @MainActor
    static func main() async throws {
        let bet = Bet(
            title: "验证个人工具需求",
            sixWeekOutcome: "十四天内让三个人完成一次真实试用",
            riskiestAssumption: "这个问题是否足够痛，值得改变现有做法",
            horizonDays: 14,
            evidenceGoal: "三次真实尝试"
        )
        var data = BetterData()
        data.bets = [bet]

        let service = CodexPlanningService()
        await service.generate(from: data)
        if let error = service.errorMessage {
            throw SmokeFailure.failed(error)
        }
        guard let suggestion = service.suggestion else {
            throw SmokeFailure.failed("Codex 没有返回建议")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(suggestion), as: UTF8.self))
    }
}
