// swift-tools-version: 5.9

import PackageDescription

// The core logic and its tests build here (`swift test`). The app itself, its
// widget, and its App Intents build through LockIn.xcodeproj, which XcodeGen
// generates from project.yml — SwiftPM cannot produce widget extensions or
// App Intents metadata.
let package = Package(
    name: "LockIn",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
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
                "Supporting",
                "UI",
                "Widget",
                "Tests"
            ],
            sources: [
                "Core",
                "Models"
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
