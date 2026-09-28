import Foundation
import SkillLockKit

/// One row in the demo's list — a skill plus the verdict a CI gate would
/// reach for it, so the view never has to re-derive governance logic itself.
struct SkillRow: Identifiable {
    let id: String
    let drift: SkillDrift?
    let verdict: SkillGovernanceVerdict?

    var name: String { id }

    var statusLabel: String {
        guard let drift else { return "Locked — matches live export" }
        switch drift {
        case .added: return "Added in live toolchain — not vendored"
        case .removed: return "Removed from live toolchain — still locked"
        case .changed: return "Changed — content differs from the lockfile"
        }
    }

    var isFailing: Bool {
        if case .unacknowledged = verdict { return true }
        return false
    }
}

@MainActor
final class SkillLockDemoViewModel: ObservableObject {
    @Published private(set) var rows: [SkillRow] = []
    @Published private(set) var failingCount: Int = 0
    @Published var selectedRowID: String?

    let locked: SkillLockfile
    let live: SkillLockfile
    let policy: SkillGovernancePolicy

    init(locked: SkillLockfile, live: SkillLockfile, policy: SkillGovernancePolicy) {
        self.locked = locked
        self.live = live
        self.policy = policy
        recompute()
    }

    private func recompute() {
        let drifts = SkillDriftDetector.diff(locked: locked, live: live)
        let verdicts = policy.evaluate(drifts)
        var driftByName: [String: (SkillDrift, SkillGovernanceVerdict)] = [:]
        for (drift, verdict) in zip(drifts, verdicts) {
            driftByName[drift.skillName] = (drift, verdict)
        }

        let allNames = Set(locked.entries.keys).union(live.entries.keys)
        rows = allNames.sorted().map { name in
            if let (drift, verdict) = driftByName[name] {
                return SkillRow(id: name, drift: drift, verdict: verdict)
            }
            return SkillRow(id: name, drift: nil, verdict: nil)
        }
        failingCount = rows.filter(\.isFailing).count
    }

    var selectedDrift: SkillDrift? {
        guard let selectedRowID else { return nil }
        return rows.first(where: { $0.id == selectedRowID })?.drift
    }

    /// The scenario the article and the README both describe: a lockfile
    /// committed against one Xcode 27.2 export, diffed against a second,
    /// later 27.2 export. Same Xcode *version label* on both sides — the
    /// flagship `swiftui-specialist` case below still shows real drift,
    /// because the lockfile compares content hashes, never the label.
    static func sampleFleetScenario() -> SkillLockDemoViewModel {
        var locked = SkillLockfile()
        // The flagship case: locked under "27.2", content A.
        locked.lock(SkillDefinition(
            name: "swiftui-specialist",
            version: "27.2",
            markdownContent: "Prefer static linkage for leaf modules; avoid dynamic frameworks below 12 targets.",
            sourceToolchain: "Xcode 27.2"
        ))
        locked.lock(SkillDefinition(
            name: "uikit-app-modernization",
            version: "27.0",
            markdownContent: "Migrate UIKit view controllers to host SwiftUI incrementally via UIHostingController.",
            sourceToolchain: "Xcode 27.0"
        ))
        locked.lock(SkillDefinition(
            name: "test-modernizer",
            version: "27.0",
            markdownContent: "Convert XCTest cases to Swift Testing @Test functions where there is no XCUIElement dependency.",
            sourceToolchain: "Xcode 27.0"
        ))
        locked.lock(SkillDefinition(
            name: "c-bounds-safety",
            version: "27.0",
            markdownContent: "Flag unchecked pointer arithmetic in C interop shims; suggest BoundsChecked wrappers.",
            sourceToolchain: "Xcode 27.0"
        ))

        var live = SkillLockfile()
        // Unchanged — identical content, so no drift is reported for this one.
        live.lock(SkillDefinition(
            name: "test-modernizer",
            version: "27.0",
            markdownContent: "Convert XCTest cases to Swift Testing @Test functions where there is no XCUIElement dependency.",
            sourceToolchain: "Xcode 27.2"
        ))
        // Changed: SAME "27.2" version label as the locked copy above, but the
        // advice flipped underneath it. A version check would see "27.2 ==
        // 27.2" and wave this through; the content hash catches it.
        live.lock(SkillDefinition(
            name: "swiftui-specialist",
            version: "27.2",
            markdownContent: "Prefer dynamic frameworks for leaf modules; static linkage now regresses incremental build time.",
            sourceToolchain: "Xcode 27.2"
        ))
        // c-bounds-safety and uikit-app-modernization are both absent from
        // this live export — genuinely removed, not just left unmentioned.
        // Added in a point release, never vendored.
        live.lock(SkillDefinition(
            name: "app-resizability",
            version: "27.1",
            markdownContent: "Audit fixed-frame modifiers ahead of iPhone Duo's variable-width scenes.",
            sourceToolchain: "Xcode 27.1"
        ))

        var policy = SkillGovernancePolicy()
        // uikit-app-modernization's removal was reviewed and accepted (it was
        // folded into swiftui-specialist upstream) — this is the one drift
        // that passes the gate. swiftui-specialist's content change,
        // c-bounds-safety's removal, and app-resizability's addition are all
        // left unacknowledged on purpose, so the demo's CI banner fails —
        // that failure is the point: nobody has reviewed them yet.
        policy.acknowledgeRemoval("uikit-app-modernization")

        return SkillLockDemoViewModel(locked: locked, live: live, policy: policy)
    }
}
