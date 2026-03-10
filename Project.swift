import ProjectDescription

let project = Project(
  name: "supacode",
  settings: .settings(
    base: [
      "CLANG_ENABLE_MODULES": "YES",
      "CODE_SIGN_STYLE": "Automatic",
      "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
      "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
      "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
      "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
      "SWIFT_VERSION": "6.0",
    ],
    configurations: [
      .debug(name: .debug, xcconfig: "Configurations/Project.xcconfig"),
      .release(name: .release, xcconfig: "Configurations/Project.xcconfig"),
    ],
    defaultSettings: .essential
  ),
  targets: [
    .target(
      name: "supacode",
      destinations: .macOS,
      product: .app,
      bundleId: "app.supabit.supacode",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .extendingDefault(with: [
        "NSAppleEventsUsageDescription": "A program running within Supacode would like to use AppleScript.",
        "NSBluetoothAlwaysUsageDescription": "A program running within Supacode would like to use Bluetooth.",
        "NSCalendarsUsageDescription": "A program running within Supacode would like to access your Calendar.",
        "NSCameraUsageDescription": "A program running within Supacode would like to use the camera.",
        "NSContactsUsageDescription": "A program running within Supacode would like to access your Contacts.",
        "NSLocalNetworkUsageDescription": "A program running within Supacode would like to access the local network.",
        "NSLocationUsageDescription": "A program running within Supacode would like to access your location information.",
        "NSMicrophoneUsageDescription": "A program running within Supacode would like to use your microphone.",
        "NSMotionUsageDescription": "A program running within Supacode would like to access motion data.",
        "NSPhotoLibraryUsageDescription": "A program running within Supacode would like to access your Photo Library.",
        "NSRemindersUsageDescription": "A program running within Supacode would like to access your reminders.",
        "NSSpeechRecognitionUsageDescription": "A program running within Supacode would like to use speech recognition.",
        "NSSystemAdministrationUsageDescription": "A program running within Supacode requires elevated privileges.",
        "SUFeedURL": "https://supacode.sh/download/latest/appcast.xml",
        "SUPublicEDKey": "eBdTbl+6sR8gxO1zyzyvdQHuJrXMLxD31oCc+JoW5jo=",
        "SUEnableAutomaticChecks": true,
        "SUAutomaticallyUpdate": true,
        "UTExportedTypeDeclarations": [
          [
            "UTTypeIdentifier": "sh.supacode.ghosttySurfaceId",
            "UTTypeDescription": "Supacode Ghostty Surface Identifier",
            "UTTypeConformsTo": [
              "public.data",
            ],
          ],
        ],
      ]),
      sources: [
        "supacode/**",
      ],
      resources: [
        "supacode/**/*.xcassets",
        .folderReference(path: "Resources/ghostty"),
        .folderReference(path: "Resources/terminfo"),
      ],
      dependencies: [
        .external(name: "ComposableArchitecture"),
        .external(name: "Dependencies"),
        .external(name: "CasePaths"),
        .external(name: "Sparkle"),
        .external(name: "Sentry"),
        .external(name: "PostHog"),
        .xcframework(path: "Frameworks/GhosttyKit.xcframework"),
        .sdk(name: "Carbon", type: .framework),
        .sdk(name: "GameController", type: .framework),
      ],
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
          "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
          "OTHER_LDFLAGS": "$(inherited) -ObjC",
        ],
        configurations: [
          .debug(name: .debug, settings: [
            "CODE_SIGN_ENTITLEMENTS": "supacode/supacodeDebug.entitlements",
          ]),
          .release(name: .release, settings: [
            "CODE_SIGN_ENTITLEMENTS": "supacode/supacode.entitlements",
          ]),
        ],
        defaultSettings: .essential
      )
    ),
    .target(
      name: "supacodeTests",
      destinations: .macOS,
      product: .unitTests,
      bundleId: "app.supabit.supacodeTests",
      deploymentTargets: .macOS("26.1"),
      infoPlist: .default,
      sources: [
        "supacodeTests/**",
      ],
      dependencies: [
        .target(name: "supacode"),
        .external(name: "DependenciesTestSupport"),
      ]
    ),
  ],
  additionalFiles: [
    "Configurations/**",
    "supacode/**/*.entitlements",
  ],
  resourceSynthesizers: []
)
