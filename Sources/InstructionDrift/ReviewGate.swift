import Foundation

/// The state of an architecture decision record a rule cites.
public enum DecisionStatus: Equatable, Sendable {
    case accepted
    case superseded(by: String)
}

public enum RuleIssue: Equatable, Sendable {
    /// An anchor no longer exists. The rule is false today.
    case deadAnchor(String)
    /// `review-by` has passed without anyone re-confirming the rule.
    case expired(Day)
    /// The decision the rule encodes was replaced in a later ADR.
    case decisionSuperseded(String, by: String)
    /// This change touches code the rule describes. Its owner must re-read it.
    case anchoredCodeChanged([String])
    case missingOwner
    case missingReviewBy

    public enum Severity: Int, Comparable, Sendable {
        case warning, review, blocking
        public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public var severity: Severity {
        switch self {
        case .deadAnchor, .expired, .decisionSuperseded: return .blocking
        case .anchoredCodeChanged: return .review
        case .missingOwner, .missingReviewBy: return .warning
        }
    }
}

public struct RuleCheck: Equatable, Sendable {
    public let rule: InstructionRule
    public let issues: [RuleIssue]
    public var worst: RuleIssue.Severity? { issues.map(\.severity).max() }
}

public enum GateVerdict: Equatable, Sendable {
    case pass
    /// Mergeable once each listed rule's owner confirms it still holds.
    case needsReview(ruleIDs: [String])
    /// Not mergeable: at least one rule is already false.
    case blocked(ruleIDs: [String])
}

/// CODEOWNERS for agent instructions: run on every pull request.
public struct ReviewGate {
    public let rules: [InstructionRule]
    public let snapshot: RepoSnapshot
    public let decisions: [String: DecisionStatus]
    public let instructionFile: String

    public init(rules: [InstructionRule], snapshot: RepoSnapshot,
                decisions: [String: DecisionStatus] = [:], instructionFile: String = "AGENTS.md") {
        self.rules = rules
        self.snapshot = snapshot
        self.decisions = decisions
        self.instructionFile = instructionFile
    }

    /// Checks every rule against the snapshot *after* the change.
    /// - Parameters:
    ///   - changedPaths: files the pull request adds, modifies or deletes.
    ///   - acknowledged: rule ids the PR author lists as re-read (`Rules-reviewed: docc`).
    ///   - today: the day the gate runs.
    public func check(changedPaths: [String], acknowledged: Set<String> = [], today: Day) -> [RuleCheck] {
        let base = instructionFile.split(separator: "/").dropLast().joined(separator: "/")
        return rules.map { rule in
            var issues: [RuleIssue] = []
            var resolved: [String] = []
            for anchor in rule.anchors {
                if let path = snapshot.resolve(anchor, relativeTo: base) {
                    resolved.append(path)
                } else {
                    issues.append(.deadAnchor(anchor))
                }
            }
            if let reviewBy = rule.reviewBy, reviewBy < today { issues.append(.expired(reviewBy)) }
            if let id = rule.decision, case .superseded(let replacement)? = decisions[id] {
                issues.append(.decisionSuperseded(id, by: replacement))
            }
            let touched = changedPaths.filter { changed in
                resolved.contains { PathMath.path(changed, isWithin: $0) }
            }
            if !touched.isEmpty, !acknowledged.contains(rule.id) {
                issues.append(.anchoredCodeChanged(touched))
            }
            if rule.owner == nil { issues.append(.missingOwner) }
            if rule.reviewBy == nil { issues.append(.missingReviewBy) }
            return RuleCheck(rule: rule, issues: issues)
        }
    }

    public func verdict(for checks: [RuleCheck]) -> GateVerdict {
        let blocking = checks.filter { $0.worst == .blocking }.map(\.rule.id)
        if !blocking.isEmpty { return .blocked(ruleIDs: blocking) }
        let review = checks.filter { $0.worst == .review }.map(\.rule.id)
        if !review.isEmpty { return .needsReview(ruleIDs: review) }
        return .pass
    }
}
