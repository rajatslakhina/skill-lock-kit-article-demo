# SkillLockKit

A lockfile for the AI coding-agent skills your IDE bundles for you — now on its second pass, after the first version's acknowledgment gate turned out to have the exact bug it was meant to prevent.

Xcode 27 ships seven Apple-authored Agent Skills (`swiftui-specialist`,
`test-modernizer`, `c-bounds-safety`, and friends) baked into the toolchain
itself, exportable with `xcrun agent skills export`. Nothing pins them: the
export is a snapshot, not a live link, so your copy drifts silently the next
time someone re-runs the export against a newer Xcode — no diff, no PR, no
review.

**SkillLockKit** hashes the skill's actual content, commits that hash, and
diffs any live export against it. **v2 fixes a real bug from v1**: the
governance gate originally let a human acknowledge a skill "through version
27.2" — but a version label is not a promise about content, and a *second*,
unreviewed change shipped under that same "27.2" label would have sailed
straight through. The gate now keys acknowledgment on the exact content hash
a human reviewed, not the label sitting next to it.

```swift
var locked = SkillLockfile()
locked.lock(SkillDefinition(
    name: "swiftui-specialist",
    version: "27.2",
    markdownContent: skillMarkdown, // the exported skill body
    sourceToolchain: "Xcode 27.2"
))

let drifts = SkillDriftDetector.diff(locked: locked, live: liveExport)
// [.changed(name: "swiftui-specialist", locked: ..., live: ...)] even though
// both sides say "27.2" — the diff compares content hashes, not labels.
```

```swift
var policy = SkillGovernancePolicy()
policy.acknowledge("swiftui-specialist", contentHash: reviewedDefinition.contentHash)

let failures = policy.unacknowledgedDrifts(in: drifts)
// empty once THIS content hash is acknowledged; a later change under the
// same version label is unacknowledged drift again, not a free pass.
```

## What's in this repo

- `Sources/SkillLockKit/` — the library: `SkillDefinition`, a dependency-free
  FNV-1a `SkillContentHasher`, a JSON-persisted `SkillLockfile`,
  `SkillDriftDetector`, and `SkillGovernancePolicy` (hash-keyed acknowledgment).
- `Tests/SkillLockKitTests/` — 16 tests covering hashing determinism,
  whitespace-insensitivity, lockfile JSON round-trips, format-version
  rejection, all three drift kinds (added/removed/changed — including the
  "same version, different content" case the whole argument rests on),
  governance acknowledgment rules, and a dedicated regression test proving a
  stale hash-acknowledgment does not cover a new content change under an
  unchanged version label.
- `Demo.xcodeproj` — a SwiftUI app (`Demo/`) that renders a live scenario:
  a lockfile pinned against one Xcode 27.2 export, diffed against a second
  27.2 export with different content, plus a genuinely removed skill, a
  genuinely added skill, and one removal that *was* reviewed and passes —
  all reflected in a pass/fail CI-gate banner with a tap-through detail view.

## Verification status

- `swift build` and `swift test`: **passed**, 16/16 tests green
  (Swift 6.4, Linux toolchain).
- `Demo.xcodeproj/project.pbxproj` was checked programmatically for
  brace/paren balance and for every referenced object ID being defined —
  both checks pass. It consumes `SkillLockKit` via an
  `XCLocalSwiftPackageReference` with `relativePath = "."` (the package's
  own `Package.swift` sits at the repo root, next to `Demo.xcodeproj`).
- **Simulator run: not completed this run.** GUI automation against
  Xcode/Finder on this run's desktop hit unreliable coordinate targeting on a
  multi-monitor setup (a click landed on an unrelated system surface rather
  than the intended dialog), so rather than risk a mis-click against a real,
  in-use machine, the run stopped short of building on Simulator and took no
  screenshot. No screenshot is embedded here because none was taken — the
  code above is verified by the passing test suite and by the structural
  checks on the Xcode project, not by a Simulator screenshot.

## How to run it

1. Clone this repo.
2. Open `Demo.xcodeproj` in Xcode (it resolves `SkillLockKit` from the
   sibling `Package.swift` in this same repo via a local Swift package
   reference — no second repo to fetch).
3. Pick any iOS Simulator destination.
4. Build & Run.

No other setup required.

## Related

This repo picks up directly from
[vendor-skill-governance-article-demo](https://github.com/rajatslakhina/vendor-skill-governance-article-demo)
— last month's piece on the same Apple Agent Skills feature, covering
per-harness capability resolution and precedence between vendor/house/repo
skills. This repo narrows in on one specific piece of that argument (the
acknowledgment gate) and fixes a real bug in how the first version of it
was keyed.

## Article

Article: (added after publish)
