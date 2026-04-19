APP_NAME := GridMove
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
VERSION_FILE := VERSION
APP_VERSION ?= $(shell tr -d '\n' < $(VERSION_FILE))
APP_COMMIT_COUNT ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 0)
APP_COMMIT_SHA_SHORT ?= $(shell git rev-parse --short=5 HEAD 2>/dev/null || echo unknown)
BUILD_NUMBER ?= $(APP_COMMIT_COUNT)
SIGN_IDENTITY ?= -
APP_BUNDLE_ID ?= cn.mirtle.GridMove
APP_AUTHOR ?= Mirtle
APP_AUTHOR_URL ?= https://github.com/mirtlecn
PACKAGE_VERSION_INFO ?= $(APP_VERSION)($(APP_COMMIT_SHA_SHORT))
RELEASE_VERSION ?= $(word 2,$(MAKECMDGOALS))
RELEASE_TAG ?= $(if $(RELEASE_VERSION),v$(shell printf '%s' "$(RELEASE_VERSION)" | sed 's/^[vV]//'))

ifeq ($(firstword $(MAKECMDGOALS)),release)
ifneq ($(RELEASE_VERSION),)
.PHONY: $(RELEASE_VERSION)
$(RELEASE_VERSION):
	@:
endif
endif

.PHONY: build test dev run sign-app verify-app clean update-version release release-vcs

build:
	rm -rf $(DIST_DIR)
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
	@if [[ -n "$(RELEASE_VERSION)" ]]; then $(MAKE) release-vcs RELEASE_TAG="$(RELEASE_TAG)"; fi
	@release_version="$$(tr -d '\n' < $(VERSION_FILE))"; \
	release_commit_count="$$(git rev-list --count HEAD 2>/dev/null || echo 0)"; \
	$(MAKE) build APP_VERSION="$$release_version" BUILD_NUMBER="$$release_commit_count" PACKAGE_VERSION_INFO="$$release_version"

release-vcs:
	@if [[ -z "$(RELEASE_TAG)" ]]; then echo 'usage: make release v0.1.1'; exit 1; fi
	git add -A
	git commit -m "chore: release $(RELEASE_TAG)"
	git tag "$(RELEASE_TAG)"

test:
	swift test --no-parallel

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
