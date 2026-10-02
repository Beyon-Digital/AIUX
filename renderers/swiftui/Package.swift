// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUXSwiftUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "AIUXSwiftUI", targets: ["AIUXSwiftUI"])],
    targets: [
        .target(name: "AIUXSwiftUI"),
        .testTarget(name: "AIUXSwiftUITests", dependencies: ["AIUXSwiftUI"]),
    ]
)
