// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacCoolinator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacCoolinator",
            path: "Sources/MacCoolinator",
            exclude: ["Info.plist"]
        )
    ]
)
