import Foundation

/// A small, dependency-free, deterministic content hasher.
///
/// This deliberately does not reach for CryptoKit/swift-crypto: the point of
/// a skill lockfile is that it has to hash identically on every machine that
/// builds this package (Linux CI, an Intel Mac, an Apple Silicon Mac), with
/// zero platform-conditional dependency resolution. FNV-1a is not
/// cryptographically secure, but a lockfile's job here is drift *detection*
/// between a vendored copy and a live export, not tamper-proofing against an
/// adversary — a 64-bit FNV-1a hash is more than enough entropy for that.
public enum SkillContentHasher {
    private static let fnvOffsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01B3

    /// Hashes the normalized content of a skill body and returns it as a
    /// fixed-width lowercase hex string (16 characters).
    public static func hash(_ content: String) -> String {
        let normalized = normalize(content)
        var hash = fnvOffsetBasis
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash = hash.multipliedReportingOverflow(by: fnvPrime).partialValue
        }
        return String(format: "%016llx", hash)
    }

    /// Strips trailing whitespace per line and trailing blank lines so that a
    /// file re-saved with different line endings, or with one blank line
    /// added at the end, does not register as drift. Real drift is a content
    /// change; incidental whitespace churn is not.
    static func normalize(_ content: String) -> String {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                var trimmed = line
                while let last = trimmed.last, last == " " || last == "\t" || last == "\r" {
                    trimmed = trimmed.dropLast()
                }
                return trimmed
            }
        var result = Array(lines)
        while let last = result.last, last.isEmpty {
            result.removeLast()
        }
        return result.joined(separator: "\n")
    }
}
