// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InstructionDrift",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InstructionDrift", targets: ["InstructionDrift"])
    ],
    targets: [
        .target(name: "InstructionDrift"),
        .testTarget(name: "InstructionDriftTests", dependencies: ["InstructionDrift"])
    ]
)
