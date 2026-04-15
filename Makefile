APP_NAME := GridMove
DIST_DIR := dist
PACKAGE_DIR := $(DIST_DIR)/$(APP_NAME)
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_VERSION ?= 0.1.0
BUILD_NUMBER ?= 1
SIGN_IDENTITY ?= -
APP_BUNDLE_ID ?= local.mirtle.GridMove
CONFIG_PLIST := $(HOME)/Library/Application Support/GridMove/config.plist

.PHONY: build test run release package package-app sign-app verify-app clean

build:
	swift build

test:
	swift test

run:
	swift run

release:
	swift build -c release

package: release
	mkdir -p $(PACKAGE_DIR)
	cp .build/release/$(APP_NAME) $(PACKAGE_DIR)/
	cp README.md $(PACKAGE_DIR)/
	tar -czf $(DIST_DIR)/$(APP_NAME)-macos.tar.gz -C $(DIST_DIR) $(APP_NAME)

package-app: release
	rm -f "$(CONFIG_PLIST)"
	./scripts/package_app.sh \
		"$(APP_NAME)" \
		"$(APP_BUNDLE)" \
		"$(APP_BUNDLE_ID)" \
		"$(APP_VERSION)" \
		"$(BUILD_NUMBER)" \
		"$(SIGN_IDENTITY)"

sign-app:
	codesign --force --deep --sign "$(SIGN_IDENTITY)" --timestamp=none "$(APP_BUNDLE)"

verify-app:
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	spctl --assess --type execute --verbose=4 "$(APP_BUNDLE)" || true

clean:
	swift package clean
	rm -rf $(DIST_DIR)
