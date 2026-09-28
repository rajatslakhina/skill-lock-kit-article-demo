import XCTest
@testable import SkillLockKit

final class SkillLockKitTests: XCTestCase {

    // MARK: - Hashing

    func testHasherIsDeterministic() {
        let a = SkillContentHasher.hash("Use SwiftUI's new resizability APIs.")
        let b = SkillContentHasher.hash("Use SwiftUI's new resizability APIs.")
        XCTAssertEqual(a, b)
    }

    func testHasherDetectsRealContentChange() {
        let a = SkillContentHasher.hash("Prefer static linkage for module A.")
        let b = SkillContentHasher.hash("Prefer dynamic linkage for module A.")
        XCTAssertNotEqual(a, b)
    }

    func testHasherIgnoresTrailingWhitespaceAndBlankLines() {
        let a = SkillContentHasher.hash("line one\nline two\n\n\n")
        let b = SkillContentHasher.hash("line one   \nline two\r")
        XCTAssertEqual(a, b, "incidental whitespace/newline churn should not register as drift")
    }

    // MARK: - Lockfile

    func testLockfileRoundTripsThroughJSON() throws {
        var lockfile = SkillLockfile()
        lockfile.lock(SkillDefinition(name: "swiftui-specialist", version: "27.0", markdownContent: "v27.0 body", sourceToolchain: "Xcode 27.0"))
        lockfile.lock(SkillDefinition(name: "test-modernizer", version: "27.0", markdownContent: "v27.0 body", sourceToolchain: "Xcode 27.0"))

        let data = try lockfile.encoded()
        let decoded = try SkillLockfile.decode(from: data)

        XCTAssertEqual(decoded.sortedEntries.count, 2)
        XCTAssertEqual(decoded["swiftui-specialist"]?.version, "27.0")
    }

    func testLockfileRejectsFutureFormatVersion() throws {
        struct FutureLockfile: Encodable {
            let formatVersion = 999
            let entries: [String: SkillDefinition] = [:]
        }
        let data = try JSONEncoder().encode(FutureLockfile())

        XCTAssertThrowsError(try SkillLockfile.decode(from: data)) { error in
            guard case SkillLockfileError.unsupportedFormatVersion(let found, _) = error else {
                return XCTFail("expected unsupportedFormatVersion, got \(error)")
            }
            XCTAssertEqual(found, 999)
        }
    }

    func testWriteReadFileRoundTrip() throws {
        var lockfile = SkillLockfile()
        lockfile.lock(SkillDefinition(name: "c-bounds-safety", version: "27.0", markdownContent: "body", sourceToolchain: "Xcode 27.0"))

        let path = NSTemporaryDirectory() + "skill-lock-test-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }

        try lockfile.write(toFile: path)
        let reloaded = try SkillLockfile.read(fromFile: path)

        XCTAssertEqual(reloaded, lockfile)
    }

    func testEmptyPathThrows() {
        XCTAssertThrowsError(try SkillLockfile().write(toFile: ""))
        XCTAssertThrowsError(try SkillLockfile.read(fromFile: ""))
    }

    // MARK: - Drift detection (the core argument of the article)

    func testNoDriftWhenLockedMatchesLive() {
        let skill = SkillDefinition(name: "swiftui-specialist", version: "27.0", markdownContent: "shared body", sourceToolchain: "Xcode 27.0")
        let locked = SkillLockfile(entries: [skill])
        let live = SkillLockfile(entries: [skill])

        XCTAssertFalse(SkillDriftDetector.hasDrift(locked: locked, live: live))
        XCTAssertTrue(SkillDriftDetector.diff(locked: locked, live: live).isEmpty)
    }

    func testChangedContentIsDetectedEvenWithSameVersionString() {
        // This is the exact failure mode the article stakes its claim on:
        // Apple can change a skill's *instructions* between betas while
        // leaving the version label alone, so hashing content (not trusting
        // the version string) is the load-bearing design decision.
        let locked = SkillLockfile(entries: [
            SkillDefinition(name: "swiftui-specialist", version: "27.2", markdownContent: "prefer dynamic frameworks", sourceToolchain: "Xcode 27.2")
        ])
        let live = SkillLockfile(entries: [
            SkillDefinition(name: "swiftui-specialist", version: "27.2", markdownContent: "prefer static frameworks", sourceToolchain: "Xcode 27.2")
        ])

        let drifts = SkillDriftDetector.diff(locked: locked, live: live)
        XCTAssertEqual(drifts.count, 1)
        guard case .changed(let name, _, _) = drifts[0] else {
            return XCTFail("expected .changed, got \(drifts[0])")
        }
        XCTAssertEqual(name, "swiftui-specialist")
    }

    func testAddedAndRemovedSkillsAreBothReported() {
        let locked = SkillLockfile(entries: [
            SkillDefinition(name: "device-interaction", version: "27.0", markdownContent: "body", sourceToolchain: "Xcode 27.0")
        ])
        let live = SkillLockfile(entries: [
            SkillDefinition(name: "app-resizability", version: "27.1", markdownContent: "new body", sourceToolchain: "Xcode 27.1")
        ])

        let drifts = SkillDriftDetector.diff(locked: locked, live: live)
        XCTAssertEqual(drifts.count, 2)
        XCTAssertTrue(drifts.contains { if case .removed(let d) = $0 { return d.name == "device-interaction" }; return false })
        XCTAssertTrue(drifts.contains { if case .added(let d) = $0 { return d.name == "app-resizability" }; return false })
    }

    func testDriftResultIsSortedByNameForStableCIDiffs() {
        let locked = SkillLockfile()
        let live = SkillLockfile(entries: [
            SkillDefinition(name: "zzz-skill", version: "1", markdownContent: "z", sourceToolchain: "Xcode 27.0"),
            SkillDefinition(name: "aaa-skill", version: "1", markdownContent: "a", sourceToolchain: "Xcode 27.0")
        ])

        let drifts = SkillDriftDetector.diff(locked: locked, live: live)
        XCTAssertEqual(drifts.map(\.skillName), ["aaa-skill", "zzz-skill"])
    }

    // MARK: - Governance policy (the "gate it" half of the thesis)

    func testUnacknowledgedChangeFailsTheGate() {
        var policy = SkillGovernancePolicy()
        policy.acknowledge("swiftui-specialist", throughVersion: "27.1") // stale ack

        let drift = SkillDrift.changed(
            name: "swiftui-specialist",
            locked: SkillDefinition(name: "swiftui-specialist", version: "27.1", contentHash: "aaa", sourceToolchain: "Xcode 27.1"),
            live: SkillDefinition(name: "swiftui-specialist", version: "27.2", contentHash: "bbb", sourceToolchain: "Xcode 27.2")
        )

        let failures = policy.unacknowledgedDrifts(in: [drift])
        XCTAssertEqual(failures.count, 1, "an ack pinned to an older version must not cover a newer drift")
    }

    func testAcknowledgedChangeAtExactLiveVersionPasses() {
        var policy = SkillGovernancePolicy()
        policy.acknowledge("swiftui-specialist", throughVersion: "27.2")

        let drift = SkillDrift.changed(
            name: "swiftui-specialist",
            locked: SkillDefinition(name: "swiftui-specialist", version: "27.1", contentHash: "aaa", sourceToolchain: "Xcode 27.1"),
            live: SkillDefinition(name: "swiftui-specialist", version: "27.2", contentHash: "bbb", sourceToolchain: "Xcode 27.2")
        )

        XCTAssertTrue(policy.unacknowledgedDrifts(in: [drift]).isEmpty)
    }

    func testAddedSkillRequiresExplicitAddedAcknowledgement() {
        let definition = SkillDefinition(name: "app-resizability", version: "27.1", contentHash: "ccc", sourceToolchain: "Xcode 27.1")
        let drift = SkillDrift.added(definition)

        var unacknowledgedPolicy = SkillGovernancePolicy()
        XCTAssertEqual(unacknowledgedPolicy.unacknowledgedDrifts(in: [drift]).count, 1)

        unacknowledgedPolicy.acknowledge("app-resizability", throughVersion: "added")
        XCTAssertTrue(unacknowledgedPolicy.unacknowledgedDrifts(in: [drift]).isEmpty)
    }

    func testEmptyDriftListNeverFails() {
        let policy = SkillGovernancePolicy()
        XCTAssertTrue(policy.unacknowledgedDrifts(in: []).isEmpty)
    }
}
