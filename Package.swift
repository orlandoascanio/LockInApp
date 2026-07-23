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
        .executable(name: "UIConcepts", targets: ["UIConcepts"]),
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
        // Design-exploration only. Static mockups, no wiring to the real app.
        .executableTarget(
            name: "UIConcepts",
            path: "UIConcepts",
            exclude: ["renders", "README.md"]
        ),
        .testTarget(
            name: "FocusLockTests",
            dependencies: ["FocusLockCore"],
            path: "FocusLock/Tests"
        )
    ]
)
