// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
  productTypes: [
    "CasePaths": .framework,
    "CasePathsCore": .framework,
    "Clocks": .framework,
    "CombineSchedulers": .framework,
    "ComposableArchitecture": .framework,
    "ConcurrencyExtras": .framework,
    "CustomDump": .framework,
    "Dependencies": .framework,
    "DependenciesTestSupport": .framework,
    "IdentifiedCollections": .framework,
    "InternalCollectionsUtilities": .framework,
    "IssueReporting": .framework,
    "IssueReportingPackageSupport": .framework,
    "OrderedCollections": .framework,
    "Perception": .framework,
    "PerceptionCore": .framework,
    "Sharing": .framework,
    "Sharing1": .framework,
    "Sharing2": .framework,
    "SwiftNavigation": .framework,
    "SwiftUINavigation": .framework,
    "UIKitNavigation": .framework,
    "UIKitNavigationShim": .framework,
    "XCTestDynamicOverlay": .framework,
    "Sparkle": .framework,
    "Sentry": .framework,
  ]
)
#endif

let package = Package(
  name: "supacode",
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-case-paths", exact: "1.7.2"),
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.0-beta.2"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", exact: "1.10.1"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.23.1"),
    .package(url: "https://github.com/getsentry/sentry-cocoa", exact: "9.3.0"),
    .package(url: "https://github.com/PostHog/posthog-ios.git", exact: "3.38.0"),
  ]
)
