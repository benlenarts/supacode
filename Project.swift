import ProjectDescription

let ghosttyBuildRootPath: Path = ".build/ghostty"
let ghosttyXCFrameworkPath: Path = ".build/ghostty/GhosttyKit.xcframework"
let ghosttyResourcesPath: Path = ".build/ghostty/share/ghostty"
let ghosttyTerminfoPath: Path = ".build/ghostty/share/terminfo"
let ghosttyBuildScriptPath: Path = "scripts/build-ghostty.sh"
let ghosttyFingerprintInputScript = """
"${SRCROOT}/\(ghosttyBuildScriptPath.pathString)" --print-fingerprint
"""

let verifyGitWtScript = """
set -euo pipefail

wt_script="${SRCROOT}/Resources/git-wt/wt"
if [ ! -f "${wt_script}" ]; then
  echo "error: missing ${wt_script}. run: git submodule update --init Resources/git-wt" >&2
  exit 1
fi
if [ ! -x "${wt_script}" ]; then
  echo "error: ${wt_script} is not executable" >&2
  exit 1
fi
"""

let embedRuntimeResourcesScript = """
set -euo pipefail

destination_root="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
ghostty_source="${SRCROOT}/\(ghosttyResourcesPath.pathString)"
terminfo_source="${SRCROOT}/\(ghosttyTerminfoPath.pathString)"
git_wt_source="${SRCROOT}/Resources/git-wt/wt"
light_theme_source="${SRCROOT}/supacode/Resources/Themes/Supacode Light"
dark_theme_source="${SRCROOT}/supacode/Resources/Themes/Supacode Dark"
ghostty_destination="${destination_root}/ghostty"
terminfo_destination="${destination_root}/terminfo"
git_wt_destination_dir="${destination_root}/git-wt"
bin_destination_dir="${destination_root}/bin"
cli_candidates=(
  "${BUILT_PRODUCTS_DIR}/supacode"
  "${UNINSTALLED_PRODUCTS_DIR}/${PLATFORM_NAME}/supacode"
)

cli_source=""
for candidate in "${cli_candidates[@]}"; do
  if [ -x "${candidate}" ]; then
    cli_source="${candidate}"
    break
  fi
done

if [ -z "${cli_source}" ]; then
  echo "error: missing built supacode executable" >&2
  exit 1
fi

rm -rf "${ghostty_destination}" "${terminfo_destination}" "${git_wt_destination_dir}" "${bin_destination_dir}"
mkdir -p "${ghostty_destination}" "${terminfo_destination}" "${git_wt_destination_dir}" "${bin_destination_dir}"
rsync -a --delete "${ghostty_source}/" "${ghostty_destination}/"
rsync -a --delete "${terminfo_source}/" "${terminfo_destination}/"
/bin/cp -f "${git_wt_source}" "${git_wt_destination_dir}/wt"
chmod +x "${git_wt_destination_dir}/wt"
/bin/cp -f "${light_theme_source}" "${destination_root}/Supacode Light"
/bin/cp -f "${dark_theme_source}" "${destination_root}/Supacode Dark"
/bin/cp -f "${cli_source}" "${bin_destination_dir}/supacode"
"""

let project = Project(
  name: "supacode",
  settings: .settings(
    base: [
      "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
      "CLANG_ENABLE_MODULES": "YES",
      "CODE_SIGN_STYLE": "Automatic",
      "DEVELOPMENT_TEAM": "9ZLSJ2GN2B",
      "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
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
      name: "supacode-cli",
      destinations: .macOS,
      product: .commandLineTool,
      bundleId: "app.supabit.supacode.cli",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .default,
      buildableFolders: [
        "supacode-cli",
      ],
      dependencies: [
        .external(name: "ArgumentParser"),
      ],
      settings: .settings(
        base: [
          "CODE_SIGNING_ALLOWED": "NO",
          "ENABLE_HARDENED_RUNTIME": "YES",
          "PRODUCT_MODULE_NAME": "supacode_cli",
          "PRODUCT_NAME": "supacode",
          "SKIP_INSTALL": "YES",
          "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
        ],
        defaultSettings: .essential
      )
    ),
    .foreignBuild(
      name: "GhosttyKit",
      destinations: .macOS,
      script: """
        "${SRCROOT}/\(ghosttyBuildScriptPath.pathString)"
        """,
      inputs: [
        .file("mise.toml"),
        .file(ghosttyBuildScriptPath),
        .script(ghosttyFingerprintInputScript),
      ],
      output: .xcframework(path: ghosttyXCFrameworkPath, linking: .static)
    ),
    .target(
      name: "supacode",
      destinations: .macOS,
      product: .app,
      bundleId: "app.supabit.supacode",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .file(path: "supacode/Info.plist"),
      resources: [
        "supacode/Assets.xcassets",
        "supacode/notification.wav",
      ],
      buildableFolders: [
        "supacode/App",
        "supacode/Clients",
        "supacode/Commands",
        "supacode/Domain",
        "supacode/Features",
        "supacode/Infrastructure",
        "supacode/Support",
      ],
      scripts: [
        .pre(
          script: verifyGitWtScript,
          name: "Verify git-wt",
          basedOnDependencyAnalysis: false
        ),
        .post(
          script: embedRuntimeResourcesScript,
          name: "Embed Runtime Resources",
          inputPaths: [
            "$(SRCROOT)/\(ghosttyResourcesPath.pathString)",
            "$(SRCROOT)/\(ghosttyTerminfoPath.pathString)",
            "$(SRCROOT)/Resources/git-wt/wt",
            "$(SRCROOT)/supacode/Resources/Themes/Supacode Light",
            "$(SRCROOT)/supacode/Resources/Themes/Supacode Dark",
            "$(BUILT_PRODUCTS_DIR)/supacode",
            "$(UNINSTALLED_PRODUCTS_DIR)/$(PLATFORM_NAME)/supacode",
          ],
          outputPaths: [
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/ghostty",
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/terminfo",
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/git-wt/wt",
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Supacode Light",
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Supacode Dark",
            "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/bin/supacode",
          ],
          basedOnDependencyAnalysis: false
        ),
      ],
      dependencies: [
        .target(name: "GhosttyKit"),
        .target(name: "supacode-cli"),
        .external(name: "CasePaths"),
        .external(name: "ComposableArchitecture"),
        .external(name: "Dependencies"),
        .external(name: "Kingfisher"),
        .external(name: "PostHog"),
        .external(name: "Sentry"),
        .external(name: "Sharing"),
        .external(name: "Sparkle"),
      ],
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
          "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
          "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
          "AUTOMATION_APPLE_EVENTS": "YES",
          "ENABLE_APP_SANDBOX": "NO",
          "ENABLE_HARDENED_RUNTIME": "YES",
          "ENABLE_PREVIEWS": "YES",
          "ENABLE_RESOURCE_ACCESS_AUDIO_INPUT": "YES",
          "ENABLE_RESOURCE_ACCESS_CALENDARS": "YES",
          "ENABLE_RESOURCE_ACCESS_CAMERA": "YES",
          "ENABLE_RESOURCE_ACCESS_CONTACTS": "YES",
          "ENABLE_RESOURCE_ACCESS_LOCATION": "YES",
          "ENABLE_RESOURCE_ACCESS_PHOTO_LIBRARY": "YES",
          "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
          "OTHER_LDFLAGS": "$(inherited) -lc++",
          "OTHER_SWIFT_FLAGS": "$(inherited) -Xcc -Wno-incomplete-umbrella",
          "REGISTER_APP_GROUPS": "YES",
          "RUNTIME_EXCEPTION_ALLOW_DYLD_ENVIRONMENT_VARIABLES": "NO",
          "RUNTIME_EXCEPTION_ALLOW_JIT": "NO",
          "RUNTIME_EXCEPTION_ALLOW_UNSIGNED_EXECUTABLE_MEMORY": "NO",
          "RUNTIME_EXCEPTION_DEBUGGING_TOOL": "NO",
          "RUNTIME_EXCEPTION_DISABLE_EXECUTABLE_PAGE_PROTECTION": "NO",
          "RUNTIME_EXCEPTION_DISABLE_LIBRARY_VALIDATION": "NO",
          "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
          "SWIFT_EMIT_LOC_STRINGS": "YES",
        ],
        debug: [
          "CODE_SIGN_ENTITLEMENTS": "supacode/supacodeDebug.entitlements",
          "COMPILATION_CACHE_ENABLE_CACHING": "YES",
        ],
        release: [
          "CODE_SIGN_ENTITLEMENTS": "supacode/supacode.entitlements",
          "COMPILATION_CACHE_ENABLE_CACHING": "NO",
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
      buildableFolders: [
        "supacodeTests",
      ],
      dependencies: [
        .target(name: "GhosttyKit"),
        .target(name: "supacode"),
        .external(name: "Clocks"),
        .external(name: "ComposableArchitecture"),
        .external(name: "ConcurrencyExtras"),
        .external(name: "CustomDump"),
        .external(name: "Dependencies"),
        .external(name: "DependenciesTestSupport"),
        .external(name: "IdentifiedCollections"),
        .external(name: "Sharing"),
      ],
      settings: .settings(
        base: [
          "BUNDLE_LOADER": "$(TEST_HOST)",
          "STRING_CATALOG_GENERATE_SYMBOLS": "NO",
          "SWIFT_EMIT_LOC_STRINGS": "NO",
          "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/supacode.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/supacode",
        ],
        defaultSettings: .essential
      )
    ),
  ],
  additionalFiles: [
    "Configurations/**",
  ],
  resourceSynthesizers: []
)
