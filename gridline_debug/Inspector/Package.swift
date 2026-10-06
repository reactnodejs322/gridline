// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyLLMDebug",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MyLLMDebug", targets: ["MyLLMDebug"])],
    targets: [.executableTarget(name: "MyLLMDebug")]
)
