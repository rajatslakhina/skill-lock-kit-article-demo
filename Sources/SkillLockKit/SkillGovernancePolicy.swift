import Foundation

/// The verdict a CI gate should return for one drift, given a governance
/// policy. This is the "treat a skill change as a toolchain upgrade that
/// goes through the same gate as a compiler bump" prescription turned into
/// code: drift is not automatically bad, but *unacknowledged* drift is.
public enum SkillGovernanceVerdict: Equatable, Sendable {
    /// Drift exists but a human has already reviewed and accepted this exact
    /// live content.
    case acknowledged(SkillDrift)

    /// Drift exists and nothing in the policy accounts for it. This is what
    /// should fail a build: an agent's advice changed under the team and
    /// nobody signed off.
    case unacknowledged(SkillDrift)
}

/// A minimal, deliberately small governance policy: for each skill name, the
/// exact content hash a human has reviewed and accepted. Anything else is
/// unacknowledged drift and fails the gate.
///
/// This is keyed on **content hash, not version label**, on purpose. An
/// earlier draft of this policy keyed on version instead — acknowledge
/// `"swiftui-specialist"` through `"27.2"` and any future content shipped
/// under that same `27.2` label would pass forever, silently. That reopens
/// the exact hole this whole package exists to close: a version string is
/// not a promise that the content underneath it is stable. Keying on the
/// hash means a genuinely new acknowledgment is required every time the
/// content actually changes, whatever the version label says.
public struct SkillGovernancePolicy: Sendable {
    public private(set) var acknowledgedContentHashes: [String: String]

    /// Sentinel values used for `.added` / `.removed` drifts, which have no
    /// content hash to compare on the missing side. Spelled out as constants
    /// rather than magic strings so a policy file reads as an explicit
    /// decision, not a coincidence.
    public static let acknowledgedAdded = "ACKNOWLEDGED_ADDED"
    public static let acknowledgedRemoved = "ACKNOWLEDGED_REMOVED"

    public init(acknowledgedContentHashes: [String: String] = [:]) {
        self.acknowledgedContentHashes = acknowledgedContentHashes
    }

    /// Records that a human has reviewed and accepted a skill at exactly
    /// this content hash. Call this with `definition.contentHash` for the
    /// live definition you just reviewed — never with a version string.
    public mutating func acknowledge(_ skillName: String, contentHash: String) {
        acknowledgedContentHashes[skillName] = contentHash
    }

    /// Convenience for the `.added` / `.removed` cases, which have no single
    /// content hash to pin (the skill either exists or doesn't).
    public mutating func acknowledgeAddition(_ skillName: String) {
        acknowledgedContentHashes[skillName] = Self.acknowledgedAdded
    }

    public mutating func acknowledgeRemoval(_ skillName: String) {
        acknowledgedContentHashes[skillName] = Self.acknowledgedRemoved
    }

    /// Evaluates a set of drifts against this policy.
    public func evaluate(_ drifts: [SkillDrift]) -> [SkillGovernanceVerdict] {
        drifts.map { drift in
            switch drift {
            case .changed(let name, _, let live):
                if acknowledgedContentHashes[name] == live.contentHash {
                    return .acknowledged(drift)
                }
                return .unacknowledged(drift)
            case .added(let definition):
                if acknowledgedContentHashes[definition.name] == Self.acknowledgedAdded {
                    return .acknowledged(drift)
                }
                return .unacknowledged(drift)
            case .removed(let definition):
                if acknowledgedContentHashes[definition.name] == Self.acknowledgedRemoved {
                    return .acknowledged(drift)
                }
                return .unacknowledged(drift)
            }
        }
    }

    /// What a CI job should actually gate on: any unacknowledged drift fails
    /// the build. Returns the failing drifts so the job can print them.
    public func unacknowledgedDrifts(in drifts: [SkillDrift]) -> [SkillDrift] {
        evaluate(drifts).compactMap { verdict in
            if case .unacknowledged(let drift) = verdict { return drift }
            return nil
        }
    }
}
