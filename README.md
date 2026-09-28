# SkillLockKit

A lockfile for the AI coding-agent skills your IDE bundles for you.

Xcode 27 ships seven Apple-authored Agent Skills (`swiftui-specialist`,
`test-modernizer`, `c-bounds-safety`, and friends) baked into the toolchain
itself, exportable with `xcrun agent skills export`. Nothing pins them: an
engineer on Xcode 27.0 and a teammate on Xcode 27.2 can — and did, per
Apple's own beta changelogs — get materially different architectural advice
out of the *same skill name*, with no diff to review, because the thing that
changed lives inside the IDE, not the repo.

**SkillLockKit** is a small, dependency-free Swift package that treats a
team's exported skill set the way `Package.resolved` treats a dependency
graph: hash it, commit it, and diff any live export against the committed
snapshot before you trust it.

```swift
var locked = SkillLockfile()
locked.lock(SkillDefinition(
    name: "swiftui-specialist",
    version: "27.0",
    markdownContent: skillMarkdown, // the exported skill body
    sourceToolchain: "Xcode 27.0"
))

let drifts = SkillDriftDetector.diff(locked: locked, live: liveExport)
// [.changed(name: "swiftui-specialist", locked: ..., live: ...)]
```

The core design decision: drift is detected on a **content hash of the
skill's body**, not its version string — because a version label can stay
put while the instructions underneath it change. `SkillGovernancePolicy`
then turns that diff into a CI-shaped verdict: any drift nobody has
explicitly acknowledged fails the gate, exactly like an unreviewed
dependency bump would.

```swift
var policy = SkillGovernancePolicy()
policy.acknowledge("swiftui-specialist", throughVersion: "27.2") // reviewed on purpose

let failures = policy.unacknowledgedDrifts(in: drifts)
// empty once acknowledged; non-empty (and CI-failing) otherwise
```

## What's in this repo

- `Sources/SkillLockKit/` — the library: `SkillDefinition`, a dependency-free
  FNV-1a `SkillContentHasher`, a JSON-persisted `SkillLockfile`,
  `SkillDriftDetector`, and `SkillGovernancePolicy`.
- `Tests/SkillLockKitTests/` — 15 tests covering hashing determinism,
  whitespace-insensitivity, lockfile JSON round-trips, format-version
  rejection, all three drift kinds (added/removed/changed — including the
  "same version, different content" case the whole argument rests on), and
  governance acknowledgement rules.
- `Demo.xcodeproj` — a SwiftUI app (`Demo/`) that renders a live scenario:
  a lockfile pinned against Xcode 27.0, diffed against a simulated Xcode
  27.2 export, with a pass/fail CI-gate banner and a tap-through detail
  view per skill.

## Verification status

- `swift build` and `swift test`: **passed**, 15/15 tests green
  (Swift 6.4, Linux toolchain).
- **Simulator run: skipped this run.** GUI automation against Xcode/Finder
  on this run's desktop hit unreliable coordinate targeting on a
  multi-monitor setup (a click landed on an unrelated system surface rather
  than the intended dialog), so rather than risk a mis-click against a real,
  in-use machine, the run stopped short of building on Simulator and took no
  screenshot. No screenshot is embedded here because none was taken — the
  code above is verified by the passing test suite, not by a Simulator
  screenshot.

## How to run it

1. Clone this repo.
2. Open `Demo.xcodeproj` in Xcode (it resolves `SkillLockKit` from the
   sibling `Package.swift` in this same repo via a local Swift package
   reference — no second repo to fetch).
3. Pick any iOS Simulator destination.
4. Build & Run.

No other setup required.

## Article

Article: (added after publish)
