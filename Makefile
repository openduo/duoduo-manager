.PHONY: project build release run clean app dmg publish version update-version

INFO_PLIST = Config/Info.plist
VERSION ?= $(shell grep -A1 "CFBundleShortVersionString" "$(INFO_PLIST)" | grep "<string>" | sed -E 's/.*<string>(.*)<\/string>.*/\1/')

all: build

project:
	xcodegen generate

build:
	swift build

release:
	swift build -c release

run: build
	.build/debug/DuoduoManager

run-release: release
	.build/release/DuoduoManager

clean:
	swift package clean
	rm -rf .build dist

app:
	./build_app.sh build

dmg:
	./build_app.sh dmg

publish:
	./build_app.sh release
	@echo "Released version $(VERSION)"

version:
	@echo "$(VERSION)"

update-version:
	@if [ "$(NEW_VERSION)" = "$(VERSION)" ]; then \
		echo "Usage: make update-version NEW_VERSION=x.x.x"; \
		exit 1; \
	fi
	sed -i '' -e '/<key>CFBundleShortVersionString<\/key>/{n;s/<string>.*<\/string>/<string>$(NEW_VERSION)<\/string>/;}' "$(INFO_PLIST)"
	sed -i '' -e '/<key>CFBundleVersion<\/key>/{n;s/<string>.*<\/string>/<string>$(NEW_VERSION)<\/string>/;}' "$(INFO_PLIST)"
	git add $(INFO_PLIST)
	git commit -m "bump version to $(NEW_VERSION)"
	git tag -a v$(NEW_VERSION) -m "v$(NEW_VERSION)"
	git push origin main --tags
	@echo "Released v$(NEW_VERSION)"
