// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchKit",
    // macOS 14 is the floor: @Observable and Animation.smooth both land here
    // or earlier, which keeps the source free of availability branches.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchKit", targets: ["NotchKit"]),
    ],
    targets: [
        .target(name: "NotchKit"),
        .testTarget(name: "NotchKitTests", dependencies: ["NotchKit"]),
        .executableTarget(
            name: "NotchDemo",
            dependencies: ["NotchKit"],
            path: "Examples/NotchDemo"
        ),
    ]
)
