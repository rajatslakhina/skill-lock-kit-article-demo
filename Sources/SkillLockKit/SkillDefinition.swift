import Foundation

/// A single agent skill as it exists at one point in time — either the version
/// vendored into a repo's lockfile, or the version currently exported from an
/// installed IDE toolchain (e.g. `xcrun agent skills export`).
///
/// `contentHash` is computed from the skill's full Markdown body via
/// ``SkillContentHasher``, so two skills with the same declared `version`
/// string but different instructions still compare as different — the
/// version label is never trusted as a proxy for content.
public struct SkillDefinition: Codable, Equatable, Sendable {
    public let name: String
    public let version: String
    public let contentHash: String
    public let sourceToolchain: String

    public init(name: String, version: String, contentHash: String, sourceToolchain: String) {
        self.name = name
        self.version = version
        self.contentHash = contentHash
        self.sourceToolchain = sourceToolchain
    }

    /// Builds a definition directly from a skill's raw Markdown content,
    /// hashing it so callers never have to hash content themselves (and can't
    /// accidentally hash two different things the same way).
    public init(name: String, version: String, markdownContent: String, sourceToolchain: String) {
        self.name = name
        self.version = version
        self.contentHash = SkillContentHasher.hash(markdownContent)
        self.sourceToolchain = sourceToolchain
    }
}
