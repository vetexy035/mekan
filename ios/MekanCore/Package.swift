// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MekanCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "MekanCore", targets: ["MekanCore"]),
    ],
    targets: [
        .target(name: "MekanCore"),
        .testTarget(name: "MekanCoreTests", dependencies: ["MekanCore"]),
    ]
)
