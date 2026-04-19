// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "GridMove",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "GridMove",
            targets: ["GridMove"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "GridMove",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "GridMoveTests",
            dependencies: ["GridMove"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
