APP_NAME := GridMove
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
VERSION_FILE := VERSION
APP_VERSION ?= $(shell tr -d '\n' < $(VERSION_FILE))
BUILD_NUMBER ?= $(APP_VERSION)
SIGN_IDENTITY ?= -
APP_BUNDLE_ID ?= cn.mirtle.GridMove
APP_AUTHOR ?= Mirtle
APP_AUTHOR_URL ?= https://github.com/mirtlecn
APP_COMMIT_SHA ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
PACKAGE_VERSION_INFO ?= $(APP_VERSION)+$(APP_COMMIT_SHA)
RELEASE_VERSION ?= $(word 2,$(MAKECMDGOALS))

ifeq ($(firstword $(MAKECMDGOALS)),release)
ifneq ($(RELEASE_VERSION),)
.PHONY: $(RELEASE_VERSION)
$(RELEASE_VERSION):
	@:
endif
endif

.PHONY: build test dev run sign-app verify-app clean update-version release

build: clean test
	swift build -c release	
	./scripts/package_app.sh \
		"$(APP_NAME)" \
		"$(APP_BUNDLE)" \
		"$(APP_BUNDLE_ID)" \
		"$(APP_VERSION)" \
		"$(BUILD_NUMBER)" \
		"$(SIGN_IDENTITY)" \
		"$(APP_AUTHOR)" \
		"$(APP_AUTHOR_URL)" \
		"$(PACKAGE_VERSION_INFO)"

update-version:
	@if [[ -z "$(VERSION)" ]]; then echo 'usage: make update-version VERSION=v0.1.1'; exit 1; fi
	./scripts/update_version.sh "$(VERSION_FILE)" "$(VERSION)"

release:
	@if [[ -n "$(RELEASE_VERSION)" ]]; then $(MAKE) update-version VERSION="$(RELEASE_VERSION)"; fi
	$(MAKE) build APP_VERSION="$(shell tr -d '\n' < $(VERSION_FILE))" BUILD_NUMBER="$(shell tr -d '\n' < $(VERSION_FILE))" PACKAGE_VERSION_INFO="$(shell tr -d '\n' < $(VERSION_FILE))"

test:
	swift test

dev:
	swift run

run:
	swift run

sign-app:
	codesign --force --deep --sign "$(SIGN_IDENTITY)" --timestamp=none "$(APP_BUNDLE)"

verify-app:
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	spctl --assess --type execute --verbose=4 "$(APP_BUNDLE)" || true

clean:
	swift package clean
	rm -rf $(DIST_DIR)
