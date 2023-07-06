// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vtid-sync-data-source",
    platforms: [
       .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "VTIDSyncDataSource",
            targets: ["VTIDSyncDataSource"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/bungamungil/vtid-command-utils.git", exact: "0.1.8"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "VTIDSyncDataSource",
            dependencies: [
                .product(name: "VTIDCommandUtils", package: "vtid-command-utils"),
            ]
        ),
        .testTarget(
            name: "VTIDSyncDataSourceTests",
            dependencies: ["VTIDSyncDataSource"]
        ),
    ]
)
