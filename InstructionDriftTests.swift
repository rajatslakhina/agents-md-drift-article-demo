import Foundation
import XCTest
@testable import InstructionDrift

final class ReferenceExtractorTests: XCTestCase {
    func testReadsCodeSpansAndFencesButNotProse() {
        let markdown = """
        Build with `Scripts/build.sh` and read Sources/NotAReference.swift in prose.
        ```bash
        swift test --package-path Packages/Core
        ```
        """
        let refs = ReferenceExtractor.references(in: markdown)
        XCTAssertEqual(refs, [
            Reference(text: "Scripts/build.sh", line: 1),
            Reference(text: "Packages/Core", line: 3)
        ])
    }

    func testRejectsURLsFlagsPlaceholdersAndAbsolutePaths() {
        for token in ["https://x.dev/a/b", "--filter=Foo/bar", "<path>/x.swift", "$HOME/x.swift",
                      "/usr/bin/swift", "~/Library/x.plist", "**/*.swift", ".copy(\"Fixtures/a.txt"] {
            XCTAssertNil(ReferenceExtractor.normalizedPath(token), token)
        }
    }

    func testKeepsFilesByExtensionAndDirectoriesByTrailingSlash() {
        XCTAssertEqual(ReferenceExtractor.normalizedPath("Package.swift"), "Package.swift")
        XCTAssertEqual(ReferenceExtractor.normalizedPath("Nodes/"), "Nodes")
        XCTAssertEqual(ReferenceExtractor.normalizedPath("(Sources/App/App.swift),"), "Sources/App/App.swift")
        XCTAssertNil(ReferenceExtractor.normalizedPath("swiftformat"), "a bare word is not a path")
        XCTAssertNil(ReferenceExtractor.normalizedPath(".txt"), "an extension on its own is not a file")
    }

    func testSameTokenTwiceOnALineIsOneReference() {
        let refs = ReferenceExtractor.references(in: "`a/b.swift` then `a/b.swift` again\n`a/b.swift`")
        XCTAssertEqual(refs.map(\.line), [1, 2])
    }

    func testUnclosedBacktickYieldsNothing() {
        XCTAssertTrue(ReferenceExtractor.references(in: "see `Sources/Open.swift").isEmpty)
    }
}

final class RepoSnapshotTests: XCTestCase {
    let snapshot = RepoSnapshot(files: [
        "ios/AGENTS.md", "ios/Sources/Kit/Sync/Engine.swift", "Package.swift", "docs/adr/ADR-1.md"
    ])

    func testDerivesDirectories() {
        XCTAssertTrue(snapshot.exists("ios/Sources/Kit"))
        XCTAssertTrue(snapshot.exists("docs"))
        XCTAssertFalse(snapshot.exists("Sources"))
    }

    func testResolvesRelativeToTheInstructionFileThenRootThenTail() {
        XCTAssertEqual(snapshot.resolve("Sources/Kit", relativeTo: "ios"), "ios/Sources/Kit")
        XCTAssertEqual(snapshot.resolve("./Package.swift", relativeTo: "ios"), "Package.swift")
        XCTAssertEqual(snapshot.resolve("Sync/Engine.swift", relativeTo: ""), "ios/Sources/Kit/Sync/Engine.swift")
        XCTAssertNil(snapshot.resolve("Kit/Engine.swift", relativeTo: ""), "a tail must match whole segments in order")
    }

    func testClimbingAboveTheRootNeverResolves() {
        XCTAssertNil(snapshot.resolve("../../Package.swift", relativeTo: "ios"))
        XCTAssertNil(PathMath.normalize("../x"))
        XCTAssertEqual(PathMath.normalize("a/./b/../c"), "a/c")
    }
}

final class DriftAuditorTests: XCTestCase {
    func day(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: text + "T12:00:00Z") else {
            XCTFail("bad date \(text)"); return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    func testClassifiesLiveRemovedIgnoredAndUnresolved() {
        let markdown = """
        - Engine: `Sources/Kit/Engine.swift`
        - Docs: `Sources/Kit.docc/`
        - Output: `.build/debug/app`
        - Pattern: `async/await`
        """
        let history = RecordedHistory(changes: [
            .init(path: "Sources/Kit/Engine.swift", date: day("2026-01-01")),
            .init(path: "Sources/Kit/Engine.swift", date: day("2026-03-01")),
            .init(path: "Sources/Kit/Engine.swift", date: day("2026-04-01")),
            .init(path: "Sources/Kit.docc/Intro.md", date: day("2026-02-01"))
        ], ignoredPrefixes: [".build"])
        let auditor = DriftAuditor(snapshot: RepoSnapshot(files: ["AGENTS.md", "Sources/Kit/Engine.swift"]), history: history)
        let audit = auditor.audit(path: "AGENTS.md", markdown: markdown) { _ in self.day("2026-02-15") }

        XCTAssertEqual(audit.findings.map(\.status), [
            .live(path: "Sources/Kit/Engine.swift", commitsSinceWritten: 2),
            .removed(lastSeen: day("2026-02-01")),
            .ignored,
            .unresolved
        ])
        XCTAssertEqual(audit.changedSinceWritten.count, 1)
        XCTAssertEqual(audit.removed.count, 1)
    }

    func testLineWithoutABlameDateIsCheckedForExistenceOnly() {
        let history = RecordedHistory(changes: [.init(path: "a/b.swift", date: day("2026-05-01"))])
        let auditor = DriftAuditor(snapshot: RepoSnapshot(files: ["a/b.swift"]), history: history)
        let audit = auditor.audit(path: "AGENTS.md", markdown: "`a/b.swift`") { _ in nil }
        XCTAssertEqual(audit.findings.first?.status, .live(path: "a/b.swift", commitsSinceWritten: 0))
    }

    func testDirectoryAnchorCountsCommitsInsideIt() {
        let history = RecordedHistory(changes: [
            .init(path: "Sources/Kit/A.swift", date: day("2026-06-01")),
            .init(path: "Sources/KitExtras/B.swift", date: day("2026-06-01"))
        ])
        XCTAssertEqual(history.commits(touching: "Sources/Kit", after: day("2026-05-01")), 1,
                       "Sources/KitExtras is a sibling, not inside Sources/Kit")
    }
}

final class RuleParserTests: XCTestCase {
    func testParsesFieldsAndMergesExplicitAndReferencedAnchors() {
        let markdown = """
        <!-- rule id=docc owner=@docs review-by=2027-01-31 decision=ADR-14 anchors=Sources/App,Package.swift -->
        - Update `Sources/App/App.docc/` and `Package.swift`.
          Continued line with `Scripts/docs.sh`.

        Not part of the rule: `Other/File.swift`
        """
        let rules = RuleParser.rules(in: markdown)
        XCTAssertEqual(rules.count, 1)
        guard let rule = rules.first else { return XCTFail("no rule parsed") }
        XCTAssertEqual(rule.id, "docc")
        XCTAssertEqual(rule.owner, "@docs")
        XCTAssertEqual(rule.reviewBy, Day(year: 2027, month: 1, day: 31))
        XCTAssertEqual(rule.decision, "ADR-14")
        XCTAssertEqual(rule.anchors, ["Sources/App", "Package.swift", "Sources/App/App.docc", "Scripts/docs.sh"])
        XCTAssertEqual(rule.line, 1)
    }

    func testIgnoresOtherCommentsAndRejectsBadDays() {
        let rules = RuleParser.rules(in: "<!-- note -->\n<!-- rule review-by=2027-13-01 -->\n- x")
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.id, "rule-2", "a rule without an id is named after its line")
        XCTAssertNil(rules.first?.reviewBy)
        XCTAssertNil(Day("2027-02"))
        XCTAssertTrue(Day(year: 2026, month: 12, day: 31) < Day(year: 2027, month: 1, day: 1))
    }
}

final class ReviewGateTests: XCTestCase {
    func issues(_ id: String, in checks: [RuleCheck]) -> [RuleIssue] {
        checks.first { $0.rule.id == id }?.issues ?? [.missingOwner, .missingOwner]
    }

    func testSamplePullRequestIsBlockedByThreeFalseRules() {
        let checks = SampleWorkspace.checks()
        XCTAssertEqual(checks.count, 6)
        XCTAssertEqual(issues("docc", in: checks), [.deadAnchor("Sources/Pantry/Pantry.docc")])
        XCTAssertEqual(issues("networking", in: checks), [.decisionSuperseded("ADR-007", by: "ADR-019")])
        XCTAssertEqual(issues("strings", in: checks), [.expired(Day(year: 2026, month: 9, day: 30))])
        XCTAssertEqual(issues("build", in: checks), [.anchoredCodeChanged(["Scripts/build.sh"])])
        XCTAssertEqual(issues("tests", in: checks), [])
        XCTAssertEqual(issues("style", in: checks), [.missingOwner, .missingReviewBy])
        XCTAssertEqual(SampleWorkspace.gate.verdict(for: checks), .blocked(ruleIDs: ["docc", "networking", "strings"]))
    }

    func testAcknowledgingARuleClearsOnlyTheReviewIssue() {
        let checks = SampleWorkspace.checks(acknowledged: ["build", "docc"])
        XCTAssertEqual(issues("build", in: checks), [])
        XCTAssertEqual(issues("docc", in: checks), [.deadAnchor("Sources/Pantry/Pantry.docc")],
                       "you can't acknowledge a rule into being true")
    }

    func testFixedInstructionsLeaveOnlyAReview() {
        let gate = SampleWorkspace.fixedGate
        let checks = gate.check(changedPaths: SampleWorkspace.changedPaths, today: SampleWorkspace.today)
        XCTAssertEqual(gate.verdict(for: checks), .needsReview(ruleIDs: ["build", "docc"]),
                       "the moved catalog is anchored by docc, so its owner re-reads it")
        let acknowledged = gate.check(changedPaths: SampleWorkspace.changedPaths,
                                      acknowledged: ["build", "docc"], today: SampleWorkspace.today)
        XCTAssertEqual(gate.verdict(for: acknowledged), .pass)
    }

    func testReviewByOnTheDayItselfIsNotExpired() {
        let gate = ReviewGate(rules: RuleParser.rules(in: "<!-- rule id=a owner=@x review-by=2026-10-28 -->\n- y"),
                              snapshot: RepoSnapshot(files: []))
        let checks = gate.check(changedPaths: [], today: Day(year: 2026, month: 10, day: 28))
        XCTAssertEqual(checks.first?.issues, [])
    }
}

final class FieldStudyTests: XCTestCase {
    func testTotalsMatchThePerRepoRows() {
        let repos = FieldStudy.repos
        XCTAssertEqual(repos.count, 18)
        XCTAssertEqual(repos.map(\.instructionFiles).reduce(0, +), FieldStudy.instructionFiles)
        XCTAssertEqual(repos.map(\.references).reduce(0, +), FieldStudy.references)
        XCTAssertEqual(repos.map(\.live).reduce(0, +), FieldStudy.live)
        XCTAssertEqual(repos.map(\.changedSinceWritten).reduce(0, +), FieldStudy.changedSinceWritten)
        XCTAssertEqual(repos.map(\.fiveOrMore).reduce(0, +), FieldStudy.fiveOrMore)
        XCTAssertEqual(repos.map(\.removed).reduce(0, +), FieldStudy.flaggedRemoved)
        XCTAssertEqual(repos.map(\.confirmedGone).reduce(0, +), FieldStudy.confirmedFalse)
        XCTAssertTrue(repos.allSatisfy { $0.confirmedGone <= $0.removed })
        XCTAssertTrue(repos.allSatisfy { $0.changedSinceWritten <= $0.live && $0.fiveOrMore <= $0.changedSinceWritten })
    }

    func testTheNumbersTheArticleQuotes() {
        XCTAssertEqual(FieldStudy.instructionFiles, 37)
        XCTAssertEqual(FieldStudy.references, 779)
        XCTAssertEqual(FieldStudy.live, 664)
        XCTAssertEqual(FieldStudy.changedSinceWritten, 455)
        XCTAssertEqual(FieldStudy.fiveOrMore, 197)
        XCTAssertEqual(FieldStudy.flaggedRemoved, 4)
        XCTAssertEqual(FieldStudy.confirmedFalse, 3)
        XCTAssertEqual(Int((FieldStudy.changedShare * 100).rounded()), 69)
    }
}
