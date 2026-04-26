// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaddleMapper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PaddleMapper", targets: ["PaddleMapper"])
    ],
    targets: [
        .executableTarget(
            name: "PaddleMapper",
            path: "Sources/PaddleMapper",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
