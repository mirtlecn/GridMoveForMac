APP_NAME := GridMove
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_VERSION ?= 0.1.0
BUILD_NUMBER ?= 1
SIGN_IDENTITY ?= -
APP_BUNDLE_ID ?= local.mirtle.GridMove
CONFIG_JSON := $(HOME)/.config/GridMove/config.json

.PHONY: build test check dev run release sign-app verify-app clean

build: test release
	rm -f "$(CONFIG_JSON)"
	rm -rf "$(DIST_DIR)/$(APP_NAME)" "$(DIST_DIR)/$(APP_NAME)-macos.tar.gz" "$(DIST_DIR)/$(APP_NAME).zip" "$(DIST_DIR)/$(APP_NAME).dmg"
	./scripts/package_app.sh \
		"$(APP_NAME)" \
		"$(APP_BUNDLE)" \
		"$(APP_BUNDLE_ID)" \
		"$(APP_VERSION)" \
		"$(BUILD_NUMBER)" \
		"$(SIGN_IDENTITY)"

test:
	swift test

check: test

dev:
	swift run

run:
	swift run

release:
	swift build -c release

sign-app:
	codesign --force --deep --sign "$(SIGN_IDENTITY)" --timestamp=none "$(APP_BUNDLE)"

verify-app:
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	spctl --assess --type execute --verbose=4 "$(APP_BUNDLE)" || true

clean:
	swift package clean
	rm -rf $(DIST_DIR)
