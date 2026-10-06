// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gridline",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Gridline", targets: ["Gridline"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.18.0")
    ],
    targets: [
        .executableTarget(name: "Gridline", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")])
    ]
)
