// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuoduoManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DuoduoManager",
            targets: ["DuoduoManager"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DuoduoManager",
            path: "Sources",
            resources: [
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
            ]
        )
    ]
)
