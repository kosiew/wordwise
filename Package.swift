// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WordWise",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "WordWise", targets: ["WordWise"]),
    ],
    targets: [
        .target(name: "WordWiseCore"),
        .executableTarget(name: "WordWise", dependencies: ["WordWiseCore"]),
        .testTarget(name: "WordWiseCoreTests", dependencies: ["WordWiseCore"]),
    ]
)
