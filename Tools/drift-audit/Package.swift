// swift-tools-version:5.9
// A command-line runner for the field audit. It is a separate package so the library's
// own Package.swift stays a pure library.
import PackageDescription

let package = Package(
    name: "drift-audit",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "InstructionDrift", path: "../..")],
    targets: [
        .executableTarget(
            name: "drift-audit",
            dependencies: [.product(name: "InstructionDrift", package: "InstructionDrift")]
        )
    ]
)
