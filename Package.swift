// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LockIn",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LockIn", targets: ["FocusLockApp"]),
        .library(name: "FocusLockCore", targets: ["FocusLockCore"])
    ],
    targets: [
        .target(
            name: "FocusLockCore",
            path: "FocusLock",
            exclude: [
                "App",
                "Assets.xcassets",
                "DesignSystem.swift",
                "Resources",
                "UI",
                "Tests"
            ],
            sources: [
                "Core",
                "Models"
            ]
        ),
        .executableTarget(
            name: "FocusLockApp",
            dependencies: ["FocusLockCore"],
            path: "FocusLock",
            exclude: [
                "Core",
                "Models",
                "Resources",
                "Tests"
            ],
            sources: [
                "DesignSystem.swift",
                "App",
                "UI"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "FocusLockTests",
            dependencies: ["FocusLockCore"],
            path: "FocusLock/Tests"
        )
    ]
)
