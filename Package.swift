// swift-tools-version: 5.7
import PackageDescription

// 注意: 最低系统版本为 macOS 12.0 (Monterey)。
// 代码中已避免使用 macOS 13+ 独有 API(MenuBarExtra / Window scene / openWindow /
// windowResizability / defaultSize / SMAppService), 改用等价 AppKit 实现。
let package = Package(
    name: "PaddleMapper",
    platforms: [.macOS(.v12)],
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
