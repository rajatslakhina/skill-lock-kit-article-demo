// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SkillLockKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SkillLockKit",
            targets: ["SkillLockKit"]
        )
    ],
    targets: [
        .target(
            name: "SkillLockKit",
            path: "Sources/SkillLockKit"
        ),
        .testTarget(
            name: "SkillLockKitTests",
            dependencies: ["SkillLockKit"],
            path: "Tests/SkillLockKitTests"
        )
    ]
)
