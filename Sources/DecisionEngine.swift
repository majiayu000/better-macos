import Foundation

enum DecisionEngine {
    static func rank(_ candidates: [ActionCandidate]) -> [ScoredCandidate] {
        candidates
            .map(score)
            .sorted {
                if $0.score == $1.score {
                    return $0.candidate.action.localizedStandardCompare($1.candidate.action) == .orderedAscending
                }
                return $0.score > $1.score
            }
    }

    static func score(_ candidate: ActionCandidate) -> ScoredCandidate {
        var value = 2
        var reasons = ["直接推进一条当前押注 +2"]

        if candidate.evidenceKind.isExternal {
            value += 4
            reasons.append("会取得外部行为证据 +4")
        } else {
            reasons.append("证据仍主要来自内部")
        }
        if candidate.validatesRiskiestAssumption {
            value += 3
            reasons.append("验证最危险假设 +3")
        }
        if candidate.evidenceWithin48Hours {
            value += 3
            reasons.append("48 小时内能见到证据 +3")
        }
        if candidate.fitsOneFocusBlock {
            value += 2
            reasons.append("一个专注段内可完成 +2")
        }
        if candidate.expandsMaintenanceSurface {
            value -= 5
            reasons.append("新开项目或扩大维护面 -5")
        }

        return ScoredCandidate(candidate: candidate, score: value, reasons: reasons)
    }
}
