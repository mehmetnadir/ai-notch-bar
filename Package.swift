// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "NotchHub",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
  ],
  targets: [
    .executableTarget(
      name: "NotchHub",
      path: "NotchHub"
    ),
    .executableTarget(
      name: "NotchHubCLI",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "NotchHubCLI"
    )
  ]
)
