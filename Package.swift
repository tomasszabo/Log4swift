// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Log4swift",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v9)
    ],
    products: [
        .library(name: "Log4swift", targets: ["Log4swift"])
    ],
    targets: [
        .target(
            name: "Log4swiftASL",
            path: "Log4swift/Objective-c wrappers",
            publicHeadersPath: ".",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .target(
            name: "Log4swiftNSLogger",
            path: "Third parties/NSLogger",
            exclude: ["LICENSE", "CREDITS"],
            sources: ["LoggerClient.m"],
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS]))
            ]
        ),
        .target(
            name: "Log4swift",
            dependencies: [
                "Log4swiftASL",
                .target(name: "Log4swiftNSLogger", condition: .when(platforms: [.macOS, .iOS, .tvOS]))
            ],
            path: "Log4swift",
            exclude: ["Objective-c wrappers", "log4swift.h"]
        ),
        .testTarget(
            name: "Log4swiftTests",
            dependencies: ["Log4swift"],
            path: "Log4swiftTests",
            exclude: [
                "Info.plist",
                "PatternFormatterTests.swift",
                "Appenders/ASLAppenderTests.swift",
                "Appenders/AppleUnifiedLoggerAppenderTests.swift",
                "Appenders/NSLoggerAppenderTests.swift"
            ],
            resources: [.copy("Resources")]
        )
    ],
    swiftLanguageModes: [.v6]
)
