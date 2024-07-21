// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebImage",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "WebImage", targets: ["WebImage"]),
    ],
    targets: [
        .target(name: "BlurHash"),
        .target(
            name: "WebImage",
            dependencies: ["BlurHash"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(name: "WebImageTests", dependencies: ["WebImage"]),
    ]
)
