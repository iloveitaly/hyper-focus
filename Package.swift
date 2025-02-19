// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hyper-focus",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        // TODO: https://github.com/envoy/Embassy/pull/110
        .package(url: "https://github.com/envoy/Ambassador", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
        .package(url: "https://github.com/rymcol/SwiftCron.git", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "hyper-focus",
            dependencies: [
                "Ambassador",
                "SwiftCron",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "hyper-focusTests",
            dependencies: ["hyper-focus"]
        ),
    ]
)
