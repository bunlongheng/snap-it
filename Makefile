# Snap It builds with the Swift toolchain that ships with the Command Line
# Tools. No Xcode, no package manager, no third party dependencies.

APP        := Snap It
BUNDLE_ID  := com.bunlongheng.snapit
VERSION    := 1.0.0
DEPLOY_MIN := 13.0

BUILD      := build
APP_BUNDLE := $(BUILD)/$(APP).app
KIT_SRC    := $(wildcard Sources/SnapItKit/*.swift)
APP_SRC    := $(wildcard Sources/SnapIt/*.swift)
TEST_SRC   := $(wildcard Tests/*.swift)

SWIFTC     := swiftc
ARCHS      := arm64 x86_64
FLAGS      := -O -swift-version 5 -framework Cocoa -framework Carbon -framework ServiceManagement

.PHONY: all build app test lint run install uninstall reset-permission import-divvy clean dev-web

all: app

## Compile a universal binary of the app.
build:
	@mkdir -p $(BUILD)
	@for arch in $(ARCHS); do \
		echo "  compiling $$arch"; \
		$(SWIFTC) $(FLAGS) -target $$arch-apple-macosx$(DEPLOY_MIN) \
			-o $(BUILD)/SnapIt-$$arch $(KIT_SRC) $(APP_SRC) || exit 1; \
	done
	@lipo -create $(foreach arch,$(ARCHS),$(BUILD)/SnapIt-$(arch)) -output $(BUILD)/SnapIt
	@rm -f $(foreach arch,$(ARCHS),$(BUILD)/SnapIt-$(arch))

## Assemble Snap It.app, icon included.
app: build
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	@cp $(BUILD)/SnapIt "$(APP_BUNDLE)/Contents/MacOS/SnapIt"
	@sed -e 's/__VERSION__/$(VERSION)/g' -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
		-e 's/__MIN_OS__/$(DEPLOY_MIN)/g' Resources/Info.plist > "$(APP_BUNDLE)/Contents/Info.plist"
	@bash scripts/make-icns.sh assets/icon.png "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@printf 'APPL????' > "$(APP_BUNDLE)/Contents/PkgInfo"
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || \
		echo "  note: ad hoc signing unavailable, the app still runs"
	@echo "built $(APP_BUNDLE)"

## Run the unit tests.
test:
	@mkdir -p $(BUILD)
	@$(SWIFTC) -swift-version 5 -o $(BUILD)/snapit-tests $(KIT_SRC) $(TEST_SRC)
	@$(BUILD)/snapit-tests

## Fail on any compiler warning.
lint:
	@bash scripts/lint.sh

## Build, install to /Applications and launch.
install: app
	@osascript -e 'quit app "Snap It"' 2>/dev/null || true
	@rm -rf "/Applications/$(APP).app"
	@cp -R "$(APP_BUNDLE)" "/Applications/$(APP).app"
	@open "/Applications/$(APP).app"
	@echo "installed /Applications/$(APP).app"

## Clear Snap It's Accessibility grant. Rebuilding changes the app's ad hoc
## signature, which makes macOS stop trusting the old grant while still
## listing it, so a rebuild needs the entry reset and re-approved once.
reset-permission:
	@tccutil reset Accessibility $(BUNDLE_ID) 2>/dev/null || true
	@echo "cleared. Approve Snap It once in Privacy & Security, Accessibility."

uninstall:
	@osascript -e 'quit app "Snap It"' 2>/dev/null || true
	@rm -rf "/Applications/$(APP).app"
	@echo "removed /Applications/$(APP).app"

## Build and run straight from ./build.
run: app
	@osascript -e 'quit app "Snap It"' 2>/dev/null || true
	@open "$(APP_BUNDLE)"

## Import Divvy's saved shortcuts into the Snap It config.
import-divvy:
	@/usr/bin/python3 scripts/import-divvy.py

## Serve the landing page locally.
dev-web:
	@python3 -m http.server 4477 --directory web

clean:
	@rm -rf $(BUILD)
