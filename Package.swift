// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Marvin",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "Marvin", targets: ["Marvin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        .target(name: "Marvin", dependencies: [
            .product(name: "Vapor", package: "vapor"),
        ]),
        .target(name: "Dev", dependencies: ["Marvin"]),
        .testTarget(name: "AppTests", dependencies: ["Marvin"])
    ]
)

