// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CharacterFolio",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FolioCore", targets: ["FolioCore"]),
        .library(name: "FolioPDF", targets: ["FolioPDF"]),
        .executable(name: "CharacterFolio", targets: ["FolioApp"]),
        .executable(name: "FolioChecks", targets: ["FolioChecks"])
    ],
    targets: [
        .target(name: "FolioCore", resources: [.process("Resources")]),
        .target(name: "FolioPDF", dependencies: ["FolioCore"]),
        .executableTarget(name: "FolioApp", dependencies: ["FolioCore", "FolioPDF"]),
        .executableTarget(name: "FolioPDFChecks", dependencies: ["FolioCore", "FolioPDF"], path: "Tests/FolioPDFChecks"),
        // Runs without Xcode's XCTest/Testing frameworks, including on Command Line Tools-only Macs.
        .executableTarget(name: "FolioChecks", dependencies: ["FolioCore"], path: "Tests/FolioCoreTests")
    ]
)
