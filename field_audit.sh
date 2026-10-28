#!/usr/bin/env bash
# Re-runs the field audit: clones each repo at the audited commit, runs Tools/drift-audit,
# and rebuilds docs/field-audit/summary.json. Needs git, Swift 5.9+ and python3.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$ROOT/docs/field-audit/raw"
swift build -c release --package-path "$ROOT/Tools/drift-audit"
CLI="$ROOT/Tools/drift-audit/.build/release/drift-audit"
while read -r repo sha; do
  dir="$WORK/${repo/\//_}"
  [ -d "$dir" ] || git clone -q --filter=blob:none "https://github.com/$repo.git" "$dir"
  git -C "$dir" checkout -q "$sha"
  "$CLI" "$dir" > "$ROOT/docs/field-audit/raw/${repo/\//_}.json"
  echo "audited $repo@${sha:0:12}"
done <<'REPOS'
AudioKit/AudioKit c358c15fdcdd0e78c4b4988f5c532c7cfb5c2eeb
OpenSwiftUIProject/OpenSwiftUI 352f8560db3fc5c99d24edf51f4d7628528ef9a0
SwiftedMind/SwiftAgent 48bfda9219a5014c117aff3294e7987e17218a9d
Zcash/ZcashLightClientKit ebd0adda8e7328f4ca2c988fb615a222f54f14f3
d-date/google-mlkit-swiftpm 1518c5f8cd3b7b5e72d1520a45b89686d51fe5dd
getpara/examples-hub 2ef3b9857b9979af2058ec5039de553aaf71e7ba
jazzyalex/agent-sessions 8ca7aa603fe5c8b098cf4a4c771fb089219659d3
jtvargas/snipkey 7797d3992da53369ee034ba1e483bdc4db859c4d
klaviyo/klaviyo-swift-sdk 8be29497918589dd56071d47ff8e39a1d995176e
krispuckett/SwiftUIShaders 6b644a8bd4f3131401bd6765990e476352d3cdef
ldomaradzki/xcsift 5e8da86c1471f6b95fcd1932e3586a1b509f7edc
manaflow-ai/cmux d86be9deea7eedb8220143cd074346912ce5263a
marmelroy/PhoneNumberKit 169ab10234347fb19b37441f2867ace896a284b0
microsoft/SwiftStreamingMarkdown 95bb755a9b23a1aea8682b9ebc912cb72b176c95
persona-id/persona-ios-sdk c80e60d62cb6ea901dc41113597a54e3dbf3ac40
peterdsp/kujto 51acf352b120c53d562ce7f1f42f48c03c8bea61
sozercan/kaset 4c59ff259d853f1cc328597f5adccf2a291c2fa7
spruceid/sprucekit-mobile 786bba7facba702c39049b9e959b6562b32c357a
REPOS
python3 "$ROOT/Scripts/summarize_field_audit.py" "$ROOT/docs/field-audit"
