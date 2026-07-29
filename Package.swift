// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "clamshellctl",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "clamshellctl", targets: ["ClamshellCLI"]),
    .executable(name: "clamshellctl-helper", targets: ["ClamshellHelper"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      from: "1.8.0"
    )
  ],
  targets: [
    .target(name: "ClamshellCore"),
    .executableTarget(
      name: "ClamshellCLI",
      dependencies: [
        "ClamshellCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(
      name: "ClamshellHelper",
      dependencies: ["ClamshellCore"]
    ),
    .testTarget(name: "ClamshellCoreTests", dependencies: ["ClamshellCore"]),
    .testTarget(
      name: "ClamshellCLITests",
      dependencies: [
        "ClamshellCLI",
        "ClamshellCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
  ]
)
