import ProjectDescription

let project = Project(
    name: "ClaudeApproval",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        ],
        debug: [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        ]
    ),
    targets: [
        // MARK: - Domain Layer
        .target(
            name: "Domain",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.onegai.claudeapproval.domain",
            deploymentTargets: .iOS("18.0"),
            sources: ["Sources/Domain/**"],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - Infrastructure Layer
        .target(
            name: "Infrastructure",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.onegai.claudeapproval.infrastructure",
            deploymentTargets: .iOS("18.0"),
            sources: ["Sources/Infrastructure/**"],
            dependencies: [
                .target(name: "Domain"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                ]
            )
        ),

        // MARK: - Main Application
        .target(
            name: "ClaudeApproval",
            destinations: .iOS,
            product: .app,
            bundleId: "com.onegai.claudeapproval",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**"],
            resources: [
                "Sources/App/Resources/**",
            ],
            entitlements: .file(path: "Sources/App/ClaudeApproval.entitlements"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "ENABLE_PREVIEWS": "YES",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "Y5856NSDZU",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                ]
            )
        ),

        // MARK: - Domain Tests
        .target(
            name: "DomainTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.onegai.claudeapproval.domain-tests",
            deploymentTargets: .iOS("18.0"),
            sources: ["Tests/DomainTests/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "ClaudeApproval",
            shared: true,
            buildAction: .buildAction(targets: ["ClaudeApproval"]),
            testAction: .targets(
                [
                    .testableTarget(target: .target("DomainTests")),
                ],
                configuration: .debug
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: .target("ClaudeApproval")
            )
        ),
    ]
)