import Foundation

/// The verdict a CI gate should return for one drift, given a governance
/// policy. This is the "treat a skill change as a toolchain upgrade that
/// goes through the same gate as a compiler bump" prescription turned into
/// code: drift is not automatically bad, but *unacknowledged* drift is.
public enum SkillGovernanceVerdict: Equatable, Sendable {
    /// Drift exists but the skill is explicitly acknowledged in this policy's
    /// `acknowledgedThroughVersion` map at a version at or after the live
    /// one — someone reviewed this bump on purpose.
    case acknowledged(SkillDrift)

    /// Drift exists and nothing in the policy accounts for it. This is what
    /// should fail a build: an agent's advice changed under the team and
    /// nobody signed off.
    case unacknowledged(SkillDrift)
}

/// A minimal, deliberately small governance policy: for each skill name, the
/// highest version a human has reviewed and accepted. Anything beyond that
/// is unacknowledged drift and fails the gate.
public struct SkillGovernancePolicy: Sendable {
    public private(set) var acknowledgedThroughVersion: [String: String]

    public init(acknowledgedThroughVersion: [String: String] = [:]) {
        self.acknowledgedThroughVersion = acknowledgedThroughVersion
    }

    public mutating func acknowledge(_ skillName: String, throughVersion version: String) {
        acknowledgedThroughVersion[skillName] = version
    }

    /// Evaluates a set of drifts against this policy. `removed` and `added`
    /// drifts are never silently acknowledged by a version string (there is
    /// no version to compare), so they always require an explicit name-level
    /// entry in `acknowledgedThroughVersion` mapped to the literal string
    /// "removed" / "added" respectively — this keeps the policy file honest
    /// about *what* was reviewed rather than rubber-stamping by coincidence.
    public func evaluate(_ drifts: [SkillDrift]) -> [SkillGovernanceVerdict] {
        drifts.map { drift in
            switch drift {
            case .changed(let name, _, let live):
                if let acknowledged = acknowledgedThroughVersion[name], acknowledged == live.version {
                    return .acknowledged(drift)
                }
                return .unacknowledged(drift)
            case .added(let definition):
                if acknowledgedThroughVersion[definition.name] == "added" {
                    return .acknowledged(drift)
                }
                return .unacknowledged(drift)
            case .removed(let definition):
                if acknowledgedThroughVersion[definition.name] == "removed" {
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
