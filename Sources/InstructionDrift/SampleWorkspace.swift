import Foundation

/// A fictional app, "Pantry", used by the demo and the tests. Its AGENTS.md has six
/// governed rules, and one pull request moves the DocC catalog and edits the build script.
public enum SampleWorkspace {
    public static let instructionFile = "AGENTS.md"

    public static let agentsMarkdown = """
    # AGENTS.md: Pantry

    ## Build
    <!-- rule id=build owner=@ios-platform review-by=2027-03-31 -->
    - Build and test with `Scripts/build.sh`. It pins the simulator and fails on warnings.

    ## Docs
    <!-- rule id=docc owner=@docs review-by=2027-01-31 -->
    - When you change public API, you MUST update the DocC catalog in `Sources/Pantry/Pantry.docc/`.

    ## Networking
    <!-- rule id=networking owner=@ios-platform review-by=2027-02-28 decision=ADR-007 -->
    - All requests go through `Sources/PantryKit/Network/APIClient.swift`. Never create a URLSession directly.

    ## Tests
    <!-- rule id=tests owner=@ios-platform review-by=2027-04-30 -->
    - New tests use Swift Testing and live in `Tests/PantryKitTests`.

    ## Strings
    <!-- rule id=strings owner=@growth review-by=2026-09-30 -->
    - User-facing copy goes in `Sources/Pantry/Localizable.xcstrings`. Ask before adding a language.

    ## Style
    <!-- rule id=style -->
    - Prefer value types. Keep files under 400 lines.
    """

    /// Tracked files after the pull request is merged.
    public static let filesAfterChange: [String] = [
        "AGENTS.md",
        "Package.swift",
        "Scripts/build.sh",
        "Sources/Pantry/PantryApp.swift",
        "Sources/Pantry/Localizable.xcstrings",
        "Sources/PantryKit/PantryKit.docc/PantryKit.md",
        "Sources/PantryKit/Network/APIClient.swift",
        "Sources/PantryKit/Network/RequestBuilder.swift",
        "Sources/PantryKit/Inventory/Item.swift",
        "Tests/PantryKitTests/ItemTests.swift",
        "docs/adr/ADR-007-single-api-client.md",
        "docs/adr/ADR-019-generated-openapi-client.md"
    ]

    /// What the pull request touches: the catalog moves into PantryKit, and the build
    /// script gains a flag.
    public static let changedPaths: [String] = [
        "Sources/Pantry/Pantry.docc/Pantry.md",
        "Sources/PantryKit/PantryKit.docc/PantryKit.md",
        "Scripts/build.sh"
    ]

    /// ADR-019 replaced the hand-written client with a generated one.
    public static let decisions: [String: DecisionStatus] = [
        "ADR-007": .superseded(by: "ADR-019"),
        "ADR-019": .accepted
    ]

    /// The day the demo gate runs.
    public static let today = Day(year: 2026, month: 10, day: 28)

    public static var rules: [InstructionRule] { RuleParser.rules(in: agentsMarkdown) }

    public static var gate: ReviewGate {
        ReviewGate(rules: rules, snapshot: RepoSnapshot(files: filesAfterChange),
                   decisions: decisions, instructionFile: instructionFile)
    }

    /// The same file after its owners fix the three false rules: the catalog path is
    /// updated, the networking rule cites ADR-019, and the strings rule is re-confirmed.
    public static var fixedMarkdown: String {
        agentsMarkdown
            .replacingOccurrences(of: "Sources/Pantry/Pantry.docc/", with: "Sources/PantryKit/PantryKit.docc/")
            .replacingOccurrences(of: "decision=ADR-007", with: "decision=ADR-019")
            .replacingOccurrences(of: "review-by=2026-09-30", with: "review-by=2027-03-31")
    }

    public static var fixedGate: ReviewGate {
        ReviewGate(rules: RuleParser.rules(in: fixedMarkdown), snapshot: RepoSnapshot(files: filesAfterChange),
                   decisions: decisions, instructionFile: instructionFile)
    }

    public static func checks(acknowledged: Set<String> = []) -> [RuleCheck] {
        gate.check(changedPaths: changedPaths, acknowledged: acknowledged, today: today)
    }
}
