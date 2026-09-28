import Foundation

/// A versioned, repo-committed snapshot of the agent skills a project has
/// deliberately vendored — the artifact this package's whole argument
/// depends on existing. Xcode 27 ships its Agent Skills *inside the IDE*,
/// unpinned to anything in source control; this is the lockfile that pins
/// them, the same way `Package.resolved` pins dependency versions.
public struct SkillLockfile: Codable, Equatable, Sendable {
    /// Schema version of the lockfile format itself, independent of any one
    /// skill's version — bumped only if the on-disk shape changes.
    public let formatVersion: Int
    public private(set) var entries: [String: SkillDefinition]

    public static let currentFormatVersion = 1

    public init(entries: [SkillDefinition] = []) {
        self.formatVersion = Self.currentFormatVersion
        var map: [String: SkillDefinition] = [:]
        for entry in entries {
            map[entry.name] = entry
        }
        self.entries = map
    }

    public mutating func lock(_ definition: SkillDefinition) {
        entries[definition.name] = definition
    }

    @discardableResult
    public mutating func remove(named name: String) -> SkillDefinition? {
        entries.removeValue(forKey: name)
    }

    /// Stable, sorted list — callers rendering a table (the demo app's list
    /// view included) should not have to re-sort a dictionary themselves.
    public var sortedEntries: [SkillDefinition] {
        entries.values.sorted { $0.name < $1.name }
    }

    public subscript(name: String) -> SkillDefinition? {
        entries[name]
    }
}

// MARK: - JSON persistence

public enum SkillLockfileError: Error, Equatable {
    case unsupportedFormatVersion(found: Int, supported: Int)
    case emptyPath
}

extension SkillLockfile {
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> SkillLockfile {
        let decoder = JSONDecoder()
        let lockfile = try decoder.decode(SkillLockfile.self, from: data)
        guard lockfile.formatVersion <= currentFormatVersion else {
            throw SkillLockfileError.unsupportedFormatVersion(
                found: lockfile.formatVersion,
                supported: currentFormatVersion
            )
        }
        return lockfile
    }

    public func write(toFile path: String) throws {
        guard !path.isEmpty else { throw SkillLockfileError.emptyPath }
        let data = try encoded()
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    public static func read(fromFile path: String) throws -> SkillLockfile {
        guard !path.isEmpty else { throw SkillLockfileError.emptyPath }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try decode(from: data)
    }
}
