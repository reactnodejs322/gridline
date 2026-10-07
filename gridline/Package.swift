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
        .executableTarget(
            name: "Gridline",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: ".",
            exclude: [
                ".build",
                "Gridline.app",
                "tools",
                "build-app.sh",
                "build-app-icon.sh",
                "template/README.md",
                "template/main_template/README.md"
            ],
            sources: [
                "Sources/Gridline/DebugEvents.swift",
                "Sources/Gridline/GridlineApp.swift",
                "Sources/Gridline/ProviderUsageService.swift",
                "Sources/Gridline/VoiceTodo.swift",
                "Sources/Gridline/Workspace.swift",
                "template/TemplateCatalog.swift",
                "template/main_template/MainTemplateDefinition.swift",
                "template/main_template/MainTemplateDropdownActionRow.swift",
                "template/main_template/MainTemplateDropdownPanel.swift",
                "template/main_template/MainTemplateWorkGroupCard.swift",
                "template/main_template/MainTemplateUsageStatusView.swift"
            ],
            resources: [.copy("usage")]
        )
    ]
)
