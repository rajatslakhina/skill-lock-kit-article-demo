import Foundation

/// One difference between a vendored lockfile and a live export of the
/// skills currently bundled in an installed toolchain.
public enum SkillDrift: Equatable, Sendable {
    /// A skill the live toolchain exports that the lockfile has never seen —
    /// e.g. a new skill added in a point release (`app-resizability` landed
    /// in Xcode 27.1 with no announcement beyond a release note).
    case added(SkillDefinition)

    /// A skill the lockfile pins that the live toolchain no longer exports.
    /// This is the dangerous direction: code review or CI configuration may
    /// still reference the skill by name.
    case removed(SkillDefinition)

    /// Same skill name, different content or version between the locked
    /// snapshot and the live export — the exact failure mode the article
    /// argues nobody is watching for: two engineers on two Xcode builds
    /// silently getting different architectural advice.
    case changed(name: String, locked: SkillDefinition, live: SkillDefinition)

    public var skillName: String {
        switch self {
        case .added(let definition): return definition.name
        case .removed(let definition): return definition.name
        case .changed(let name, _, _): return name
        }
    }

    /// A short, human-readable line suitable for a CI log or a list row.
    public var summary: String {
        switch self {
        case .added(let definition):
            return "+ \(definition.name) (\(definition.version)) — new in \(definition.sourceToolchain), not yet vendored"
        case .removed(let definition):
            return "- \(definition.name) (\(definition.version)) — locked but missing from the live toolchain"
        case .changed(let name, let locked, let live):
            return "~ \(name): \(locked.version) [\(locked.sourceToolchain)] -> \(live.version) [\(live.sourceToolchain)]"
        }
    }
}
