# Field audit: agent instructions vs the code they describe

`Tools/drift-audit` was run on 18 public Swift repositories that ship an `AGENTS.md` or `CLAUDE.md`, each at the commit listed below, on 28 Oct 2026. The repos were found through a code search for Swift projects with those files; there was no other selection. Raw per-reference output is in [`raw/`](raw), the totals in [`summary.json`](summary.json). Re-run it with `Scripts/field_audit.sh`.

These are good, actively maintained projects. Several of them edited their instruction file within the last month. That is the point of the study, not a criticism of them.

## Method

1. **Instruction files.** Every tracked `AGENTS.md` / `CLAUDE.md` (any folder, case-insensitive). Symlinks and byte-identical copies (a `CLAUDE.md` that mirrors `AGENTS.md`) are counted once.
2. **References.** Path-like tokens inside code spans and fenced code blocks only: tokens containing `/`, ending in `/`, or ending in a known file extension. URLs, flags, placeholders (`<path>`, `$VAR`), globs and absolute or home paths are skipped. A token is counted once per line.
3. **Resolution.** A reference is *live* if it names a tracked file or directory: relative to the instruction file's folder, to the repo root, or as the tail of a deeper path.
4. **Drift.** For each live reference, `git blame` gives the date its line was last edited, and `git rev-list --count --since` counts the commits that touched the target after that date.
5. **Gone.** A reference that doesn't resolve is *removed* if `git log --all` shows that a matching path was tracked at some point, *ignored* if `git check-ignore` matches it (build output, local files), and *unresolved* otherwise (prose such as `async/await`, placeholders, package slugs).

## Totals

| Repos | Instruction files | References | Live | Changed since the line was written | 5+ commits since | Flagged removed | Ignored | Unresolved |
|---|---|---|---|---|---|---|---|---|
| 18 | 37 | 779 | 664 | **455 (68.5%)** | 197 (29.7%) | 4 | 36 | 75 |

"Changed since the line was written" is not the same as "wrong". It is the number of sentences whose subject moved after they were written, with nothing in the repo asking anyone to re-read them.

## The four references flagged as removed, checked by hand

| Repo | Line | Reference | What happened | Verdict |
|---|---|---|---|---|
| ldomaradzki/xcsift | `CLAUDE.md:1041` (written 2025-12-11) | `Sources/xcsift.docc/` | The line is an **IMPORTANT ... you MUST update** rule. The catalog moved to `Sources/xcsift/xcsift.docc/` on 2026-05-25. The file was last edited 2026-10-16. | False today |
| ldomaradzki/xcsift | `CLAUDE.md:722` (written 2026-03-22) | `Tests/XcbeautifyTests.swift` | Deleted on 2026-05-12 when the core moved into separate targets. | False today |
| microsoft/SwiftStreamingMarkdown | `AGENTS.md:14` (written 2026-06-02) | `Sources/MarkdownText/UI/UIKit/` | The folder was reorganised on 2026-06-30. The file was last edited 2026-07-07. | False today |
| Zcash/ZcashLightClientKit | `AGENTS.md:257` | `zcashlc.h` | The line correctly calls it a *generated* header; the tracked copy was removed in 2022 because the build now produces it. | Tool false positive |

## Per repo

| Repo | Commit | Files | References | Live | Changed since written | 5+ commits | Flagged removed |
|---|---|---|---|---|---|---|---|
| [AudioKit/AudioKit](https://github.com/AudioKit/AudioKit/tree/c358c15fdcdd0e78c4b4988f5c532c7cfb5c2eeb) | `c358c15fdcdd` | 1 | 14 | 12 | 12 | 5 | 0 |
| [OpenSwiftUIProject/OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI/tree/352f8560db3fc5c99d24edf51f4d7628528ef9a0) | `352f8560db3f` | 1 | 13 | 12 | 8 | 5 | 0 |
| [SwiftedMind/SwiftAgent](https://github.com/SwiftedMind/SwiftAgent/tree/48bfda9219a5014c117aff3294e7987e17218a9d) | `48bfda9219a5` | 1 | 13 | 6 | 0 | 0 | 0 |
| [Zcash/ZcashLightClientKit](https://github.com/Zcash/ZcashLightClientKit/tree/ebd0adda8e7328f4ca2c988fb615a222f54f14f3) | `ebd0adda8e73` | 1 | 115 | 98 | 62 | 33 | 1 |
| [d-date/google-mlkit-swiftpm](https://github.com/d-date/google-mlkit-swiftpm/tree/1518c5f8cd3b7b5e72d1520a45b89686d51fe5dd) | `1518c5f8cd3b` | 2 | 80 | 73 | 43 | 6 | 0 |
| [getpara/examples-hub](https://github.com/getpara/examples-hub/tree/2ef3b9857b9979af2058ec5039de553aaf71e7ba) | `2ef3b9857b99` | 2 | 12 | 7 | 5 | 3 | 0 |
| [jazzyalex/agent-sessions](https://github.com/jazzyalex/agent-sessions/tree/8ca7aa603fe5c8b098cf4a4c771fb089219659d3) | `8ca7aa603fe5` | 2 | 27 | 17 | 16 | 13 | 0 |
| [jtvargas/snipkey](https://github.com/jtvargas/snipkey/tree/7797d3992da53369ee034ba1e483bdc4db859c4d) | `7797d3992da5` | 1 | 130 | 122 | 84 | 37 | 0 |
| [klaviyo/klaviyo-swift-sdk](https://github.com/klaviyo/klaviyo-swift-sdk/tree/8be29497918589dd56071d47ff8e39a1d995176e) | `8be294979185` | 1 | 4 | 3 | 2 | 0 | 0 |
| [krispuckett/SwiftUIShaders](https://github.com/krispuckett/SwiftUIShaders/tree/6b644a8bd4f3131401bd6765990e476352d3cdef) | `6b644a8bd4f3` | 2 | 10 | 10 | 8 | 0 | 0 |
| [ldomaradzki/xcsift](https://github.com/ldomaradzki/xcsift/tree/5e8da86c1471f6b95fcd1932e3586a1b509f7edc) | `5e8da86c1471` | 1 | 63 | 29 | 13 | 4 | 2 |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux/tree/d86be9deea7eedb8220143cd074346912ce5263a) | `d86be9deea7e` | 11 | 62 | 59 | 53 | 31 | 0 |
| [marmelroy/PhoneNumberKit](https://github.com/marmelroy/PhoneNumberKit/tree/169ab10234347fb19b37441f2867ace896a284b0) | `169ab1023434` | 1 | 6 | 6 | 5 | 1 | 0 |
| [microsoft/SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown/tree/95bb755a9b23a1aea8682b9ebc912cb72b176c95) | `95bb755a9b23` | 1 | 35 | 30 | 30 | 17 | 1 |
| [persona-id/persona-ios-sdk](https://github.com/persona-id/persona-ios-sdk/tree/c80e60d62cb6ea901dc41113597a54e3dbf3ac40) | `c80e60d62cb6` | 2 | 15 | 15 | 0 | 0 | 0 |
| [peterdsp/kujto](https://github.com/peterdsp/kujto/tree/51acf352b120c53d562ce7f1f42f48c03c8bea61) | `51acf352b120` | 1 | 17 | 16 | 11 | 8 | 0 |
| [sozercan/kaset](https://github.com/sozercan/kaset/tree/4c59ff259d853f1cc328597f5adccf2a291c2fa7) | `4c59ff259d85` | 1 | 14 | 12 | 8 | 7 | 0 |
| [spruceid/sprucekit-mobile](https://github.com/spruceid/sprucekit-mobile/tree/786bba7facba702c39049b9e959b6562b32c357a) | `786bba7facba` | 5 | 149 | 137 | 95 | 27 | 0 |

## Limits

- 18 repos is a small, non-random sample, and only path references are checked. A sentence can name a path that exists and still be wrong ("22 tests in ..."), and this audit can't see that.
- Commit counts on a directory include every file under it, so broad anchors such as `Sources/` drift fastest. The demo's gate deals with that by letting a rule name narrow anchors.
- Line dates come from `git blame`, so a whitespace or wording edit to a line resets its date even if nobody re-checked the path.
