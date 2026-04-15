// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "GridMove",
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
            name: "GridMove"
        ),
        .testTarget(
            name: "GridMoveTests",
            dependencies: ["GridMove"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
