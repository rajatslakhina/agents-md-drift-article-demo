import Foundation

/// The field audit behind the article: `Tools/drift-audit` run on 18 public Swift repos
/// that ship an AGENTS.md or CLAUDE.md, on 28 Oct 2026. Generated from
/// `docs/field-audit/summary.json`; the raw per-reference output is in `docs/field-audit/raw/`.
public enum FieldStudy {
    public struct RepoResult: Equatable, Sendable, Identifiable {
        public var id: String { name }
        public let name: String
        /// First 12 characters of the audited commit.
        public let head: String
        public let instructionFiles: Int
        public let references: Int
        /// References that resolve to a tracked path today.
        public let live: Int
        /// Live references whose target changed after the line naming it was last edited.
        public let changedSinceWritten: Int
        /// Live references with five or more such commits.
        public let fiveOrMore: Int
        /// References to a path that was tracked once and is gone, as flagged by the tool.
        public let removed: Int
        /// Of those, the ones confirmed by hand as instructions that are now false.
        public let confirmedGone: Int
    }

    public static let auditedOn = Day(year: 2026, month: 10, day: 28)

    public static let repos: [RepoResult] = [
        RepoResult(name: "AudioKit/AudioKit", head: "c358c15fdcdd", instructionFiles: 1, references: 14, live: 12, changedSinceWritten: 12, fiveOrMore: 5, removed: 0, confirmedGone: 0),
        RepoResult(name: "OpenSwiftUIProject/OpenSwiftUI", head: "352f8560db3f", instructionFiles: 1, references: 13, live: 12, changedSinceWritten: 8, fiveOrMore: 5, removed: 0, confirmedGone: 0),
        RepoResult(name: "SwiftedMind/SwiftAgent", head: "48bfda9219a5", instructionFiles: 1, references: 13, live: 6, changedSinceWritten: 0, fiveOrMore: 0, removed: 0, confirmedGone: 0),
        RepoResult(name: "Zcash/ZcashLightClientKit", head: "ebd0adda8e73", instructionFiles: 1, references: 115, live: 98, changedSinceWritten: 62, fiveOrMore: 33, removed: 1, confirmedGone: 0),
        RepoResult(name: "d-date/google-mlkit-swiftpm", head: "1518c5f8cd3b", instructionFiles: 2, references: 80, live: 73, changedSinceWritten: 43, fiveOrMore: 6, removed: 0, confirmedGone: 0),
        RepoResult(name: "getpara/examples-hub", head: "2ef3b9857b99", instructionFiles: 2, references: 12, live: 7, changedSinceWritten: 5, fiveOrMore: 3, removed: 0, confirmedGone: 0),
        RepoResult(name: "jazzyalex/agent-sessions", head: "8ca7aa603fe5", instructionFiles: 2, references: 27, live: 17, changedSinceWritten: 16, fiveOrMore: 13, removed: 0, confirmedGone: 0),
        RepoResult(name: "jtvargas/snipkey", head: "7797d3992da5", instructionFiles: 1, references: 130, live: 122, changedSinceWritten: 84, fiveOrMore: 37, removed: 0, confirmedGone: 0),
        RepoResult(name: "klaviyo/klaviyo-swift-sdk", head: "8be294979185", instructionFiles: 1, references: 4, live: 3, changedSinceWritten: 2, fiveOrMore: 0, removed: 0, confirmedGone: 0),
        RepoResult(name: "krispuckett/SwiftUIShaders", head: "6b644a8bd4f3", instructionFiles: 2, references: 10, live: 10, changedSinceWritten: 8, fiveOrMore: 0, removed: 0, confirmedGone: 0),
        RepoResult(name: "ldomaradzki/xcsift", head: "5e8da86c1471", instructionFiles: 1, references: 63, live: 29, changedSinceWritten: 13, fiveOrMore: 4, removed: 2, confirmedGone: 2),
        RepoResult(name: "manaflow-ai/cmux", head: "d86be9deea7e", instructionFiles: 11, references: 62, live: 59, changedSinceWritten: 53, fiveOrMore: 31, removed: 0, confirmedGone: 0),
        RepoResult(name: "marmelroy/PhoneNumberKit", head: "169ab1023434", instructionFiles: 1, references: 6, live: 6, changedSinceWritten: 5, fiveOrMore: 1, removed: 0, confirmedGone: 0),
        RepoResult(name: "microsoft/SwiftStreamingMarkdown", head: "95bb755a9b23", instructionFiles: 1, references: 35, live: 30, changedSinceWritten: 30, fiveOrMore: 17, removed: 1, confirmedGone: 1),
        RepoResult(name: "persona-id/persona-ios-sdk", head: "c80e60d62cb6", instructionFiles: 2, references: 15, live: 15, changedSinceWritten: 0, fiveOrMore: 0, removed: 0, confirmedGone: 0),
        RepoResult(name: "peterdsp/kujto", head: "51acf352b120", instructionFiles: 1, references: 17, live: 16, changedSinceWritten: 11, fiveOrMore: 8, removed: 0, confirmedGone: 0),
        RepoResult(name: "sozercan/kaset", head: "4c59ff259d85", instructionFiles: 1, references: 14, live: 12, changedSinceWritten: 8, fiveOrMore: 7, removed: 0, confirmedGone: 0),
        RepoResult(name: "spruceid/sprucekit-mobile", head: "786bba7facba", instructionFiles: 5, references: 149, live: 137, changedSinceWritten: 95, fiveOrMore: 27, removed: 0, confirmedGone: 0)
    ]

    public static let instructionFiles = 37
    public static let references = 779
    public static let live = 664
    public static let changedSinceWritten = 455
    public static let fiveOrMore = 197
    /// Flagged as removed by the tool. Checked by hand: 3 are paths that moved, and 1
    /// (`zcashlc.h`) is a header the build now generates, so it is a false positive.
    public static let flaggedRemoved = 4
    public static let confirmedFalse = 3

    /// Share of live references whose code changed after the sentence about it was written.
    public static var changedShare: Double {
        live == 0 ? 0 : Double(changedSinceWritten) / Double(live)
    }
}
