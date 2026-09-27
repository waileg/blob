// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Blob",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Blob",
            path: "Blob",
            linkerSettings: [
                .linkedFramework("Speech"),
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)