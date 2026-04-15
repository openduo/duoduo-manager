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
    dependencies: [
        .package(url: "https://github.com/kuaner/cc-reader.git", from: "1.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "DuoduoManager",
            dependencies: [
                .product(name: "CCReaderKit", package: "cc-reader")
            ],
            path: "Sources",
            resources: [
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
            ]
        )
    ]
)
