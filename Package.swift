// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CADMVVerifier",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "CADMVVerifier", targets: ["CADMVVerifier"]),
        .library(name: "CADMVScanner", targets: ["CADMVScanner"]),
        .executable(name: "CADMVVerifierSelfTest", targets: ["CADMVVerifierSelfTest"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "4.0.0" ..< "5.0.0")
    ],
    targets: [
        .target(
            name: "CADMVVerifier",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "CADMVScanner",
            dependencies: ["CADMVVerifier"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "CADMVVerifierSelfTest",
            dependencies: ["CADMVVerifier", "CADMVScanner"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
