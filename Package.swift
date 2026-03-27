// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SyncShimmer",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SyncShimmer", targets: ["SyncShimmer"]),
    ],
    targets: [
        .target(name: "SyncShimmer"),
    ]
)
