// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CacheStore",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CacheStore",
            targets: ["CacheStore"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(
            url: "https://github.com/0xOpenBytes/c",
            from: "3.0.0"
        ),
         .package(
            url: "https://github.com/0xLeif/swift-custom-dump",
            from: "2022.11.1"
         )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CacheStore",
            dependencies: [
                "c",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ]
        ),
        .testTarget(
            name: "CacheStoreTests",
            dependencies: ["CacheStore"]
        )
    ]
)
