// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package: Package = Package(
    name: "SwiftTracer",
    dependencies: [
      .package(url: "git@github.com:Prismik/SwiftWavefront.git", branch: "main"),
      .package(url: "git@github.com:apple/swift-argument-parser.git", exact: "1.4.0"),
      .package(url: "git@github.com:jkandzi/Progress.swift.git", exact: "0.4.0"),
      .package(url: "git@github.com:Prismik/kvSIMD.swift.git", branch: "main"),
      .package(url: "git@github.com:tayloraswift/swift-png.git", from: "4.4.0"),
      .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftTracer",
            dependencies: [
                .product(name: "Progress", package: "Progress.swift"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftWavefront", package: "SwiftWavefront"),
                .product(name: "kvSIMD", package: "kvSIMD.swift"),
                .product(name: "PNG", package: "swift-png"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            path: "SwiftTracer"),
        .testTarget(
            name: "SwiftTracerTest",
            dependencies: [.byName(name:"SwiftTracer")],
            path: "SwiftTracerTest")
    ]
)
