# Sensible defaults
.ONESHELL:
SHELL := bash
.SHELLFLAGS := -e -u -c -o pipefail
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Derived values (DO NOT TOUCH).
CURRENT_MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(CURRENT_MAKEFILE_PATH)))
PROJECT_WORKSPACE := $(CURRENT_MAKEFILE_DIR)/supacode.xcworkspace
APP_SCHEME := supacode
VERSION_XCCONFIG := $(CURRENT_MAKEFILE_DIR)/Configurations/Project.xcconfig
GHOSTTY_XCFRAMEWORK_PATH := $(CURRENT_MAKEFILE_DIR)/Frameworks/GhosttyKit.xcframework
GHOSTTY_RESOURCE_PATH := $(CURRENT_MAKEFILE_DIR)/Resources/ghostty
GHOSTTY_TERMINFO_PATH := $(CURRENT_MAKEFILE_DIR)/Resources/terminfo
GHOSTTY_BUILD_OUTPUTS := $(GHOSTTY_XCFRAMEWORK_PATH) $(GHOSTTY_RESOURCE_PATH) $(GHOSTTY_TERMINFO_PATH)
TUIST_GENERATION_STAMP := $(PROJECT_WORKSPACE)/.tuist-generated-stamp
TUIST_GENERATION_INPUTS := Project.swift Tuist.swift Tuist/Package.swift Tuist/Package.resolved Configurations/Project.xcconfig mise.toml
VERSION ?=
BUILD ?=
XCODEBUILD_FLAGS ?=
.DEFAULT_GOAL := help
.PHONY: build-ghostty-xcframework generate-project build-app run-app install-dev-build archive export-archive format lint check test bump-version bump-and-release log-stream

ifeq ($(CI),)
TUIST_INSTALL_FLAGS :=
else
TUIST_INSTALL_FLAGS := --force-resolved-versions
endif

help:  # Display this help.
	@-+echo "Run make with one of the following targets:"
	@-+echo
	@-+grep -Eh "^[a-z-]+:.*#" $(CURRENT_MAKEFILE_PATH) | sed -E 's/^(.*:)(.*#+)(.*)/  \1 @@@ \3 /' | column -t -s "@@@"

build-ghostty-xcframework: $(GHOSTTY_BUILD_OUTPUTS) # Build ghostty framework

$(GHOSTTY_BUILD_OUTPUTS):
	@cd $(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty && mise exec -- zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dsentry=false
	rsync -a ThirdParty/ghostty/macos/GhosttyKit.xcframework Frameworks
	@src="$(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty/zig-out/share/ghostty"; \
	dst="$(GHOSTTY_RESOURCE_PATH)"; \
	terminfo_src="$(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty/zig-out/share/terminfo"; \
	terminfo_dst="$(GHOSTTY_TERMINFO_PATH)"; \
	mkdir -p "$$dst"; \
	rsync -a --delete "$$src/" "$$dst/"; \
	mkdir -p "$$terminfo_dst"; \
	rsync -a --delete "$$terminfo_src/" "$$terminfo_dst/"

generate-project: $(TUIST_GENERATION_STAMP) # Resolve packages and generate Xcode workspace

$(TUIST_GENERATION_STAMP): $(TUIST_GENERATION_INPUTS) $(GHOSTTY_BUILD_OUTPUTS)
	mise exec -- tuist install $(TUIST_INSTALL_FLAGS)
	mise exec -- tuist generate --no-open
	touch "$@"

build-app: $(TUIST_GENERATION_STAMP) # Build the macOS app (Debug)
	bash -o pipefail -c 'xcodebuild -workspace "$(PROJECT_WORKSPACE)" -scheme "$(APP_SCHEME)" -configuration Debug build -skipMacroValidation 2>&1 | mise exec -- xcsift -qw --format toon'

run-app: build-app # Build then launch (Debug) with log streaming
	@settings="$$(xcodebuild -workspace "$(PROJECT_WORKSPACE)" -scheme "$(APP_SCHEME)" -configuration Debug -showBuildSettings -json 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	exec_name="$$(echo "$$settings" | jq -r '.[0].buildSettings.EXECUTABLE_NAME')"; \
	"$$build_dir/$$product/Contents/MacOS/$$exec_name"

install-dev-build: build-app # install dev build to /Applications
	@settings="$$(xcodebuild -workspace "$(PROJECT_WORKSPACE)" -scheme "$(APP_SCHEME)" -configuration Debug -showBuildSettings -json 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	src="$$build_dir/$$product"; \
	dst="/Applications/$$product"; \
	if [ ! -d "$$src" ]; then \
		echo "app not found: $$src"; \
		exit 1; \
	fi; \
	echo "copying $$src -> $$dst"; \
	rm -rf "$$dst"; \
	ditto "$$src" "$$dst"; \
	echo "installed $$dst"

archive: $(TUIST_GENERATION_STAMP) # Archive Release build for distribution
	bash -o pipefail -c 'xcodebuild -workspace "$(PROJECT_WORKSPACE)" -scheme "$(APP_SCHEME)" -configuration Release -archivePath build/supacode.xcarchive archive CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$$APPLE_TEAM_ID" CODE_SIGN_IDENTITY="$$DEVELOPER_ID_IDENTITY_SHA" OTHER_CODE_SIGN_FLAGS="--timestamp" -skipMacroValidation $(XCODEBUILD_FLAGS) 2>&1 | mise exec -- xcsift -qw --format toon'

export-archive: # Export xarchive
	bash -o pipefail -c 'xcodebuild -exportArchive -archivePath build/supacode.xcarchive -exportPath build/export -exportOptionsPlist build/ExportOptions.plist 2>&1 | mise exec -- xcsift -qw --format toon'

test: $(TUIST_GENERATION_STAMP)
	xcodebuild test -workspace "$(PROJECT_WORKSPACE)" -scheme "$(APP_SCHEME)" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -skipMacroValidation 2>&1

format: # Format code with swift-format (local only)
	swift-format -p --in-place --recursive --configuration ./.swift-format.json supacode supacodeTests

lint: # Lint code with swiftlint
	mise exec -- swiftlint --fix --quiet
	mise exec -- swiftlint lint --quiet --config .swiftlint.yml

check: format lint # Format and lint

log-stream: # Stream logs from the app via log stream
	log stream --predicate 'subsystem == "app.supabit.supacode"' --style compact --color always

bump-version: # Bump app version (usage: make bump-version [VERSION=x.x.x] [BUILD=123])
	@if [ -z "$(VERSION)" ]; then \
		current="$$(/usr/bin/awk -F' = ' '/^MARKETING_VERSION = [0-9.]+$$/{print $$2; exit}' "$(VERSION_XCCONFIG)")"; \
		if [ -z "$$current" ]; then \
			echo "error: MARKETING_VERSION not found"; \
			exit 1; \
		fi; \
		major="$$(echo "$$current" | cut -d. -f1)"; \
		minor="$$(echo "$$current" | cut -d. -f2)"; \
		patch="$$(echo "$$current" | cut -d. -f3)"; \
		version="$$major.$$minor.$$((patch + 1))"; \
	else \
		if ! echo "$(VERSION)" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$'; then \
			echo "error: VERSION must be in x.x.x format"; \
			exit 1; \
		fi; \
		version="$(VERSION)"; \
	fi; \
	if [ -z "$(BUILD)" ]; then \
		build="$$(/usr/bin/awk -F' = ' '/^CURRENT_PROJECT_VERSION = [0-9]+$$/{print $$2; exit}' "$(VERSION_XCCONFIG)")"; \
		if [ -z "$$build" ]; then \
			echo "error: CURRENT_PROJECT_VERSION not found"; \
			exit 1; \
		fi; \
		build="$$((build + 1))"; \
	else \
		if ! echo "$(BUILD)" | grep -qE '^[0-9]+$$'; then \
			echo "error: BUILD must be an integer"; \
			exit 1; \
		fi; \
		build="$(BUILD)"; \
	fi; \
	sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $$version/" \
		"$(VERSION_XCCONFIG)"; \
	sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $$build/" \
		"$(VERSION_XCCONFIG)"; \
	git add "$(VERSION_XCCONFIG)"; \
	git commit -m "bump v$$version"; \
	git tag -s "v$$version" -m "v$$version"; \
	echo "version bumped to $$version (build $$build), tagged v$$version"

bump-and-release: bump-version # Bump version and push tags to trigger release
	git push --follow-tags
	@tag="$$(git describe --tags --abbrev=0)"; \
	repo="$$(gh repo view --json nameWithOwner -q .nameWithOwner)"; \
	prev="$$(gh release view --json tagName -q .tagName 2>/dev/null || echo '')"; \
	tmp=$$(mktemp); \
	if [ -n "$$prev" ]; then \
		gh api "repos/$$repo/releases/generate-notes" -f tag_name="$$tag" -f previous_tag_name="$$prev" --jq '.body' > "$$tmp"; \
	else \
		gh api "repos/$$repo/releases/generate-notes" -f tag_name="$$tag" --jq '.body' > "$$tmp"; \
	fi; \
	$${EDITOR:-vim} "$$tmp"; \
	gh release create "$$tag" --notes-file "$$tmp"; \
	rm -f "$$tmp"
