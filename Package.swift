// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "code-challenge",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.7.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "code-challenge",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Parsing", package: "swift-parsing")]),
        .testTarget(
            name: "code-challengeTests",
            dependencies: ["code-challenge"]),
    ]
)
