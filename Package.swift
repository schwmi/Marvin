// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Marvin",
    products: [
        .library(name: "Marvin", targets: ["Marvin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0")
    ],
    targets: [
        .target(name: "Marvin", dependencies: ["Vapor"]),
        .target(name: "Dev", dependencies: ["Marvin"]),
        .testTarget(name: "AppTests", dependencies: ["Marvin"])
    ]
)

