.PHONY: project build release run clean app dmg publish version update-version

APP_NAME = DuoduoManager
PROJECT_YML = project.yml
VERSION ?= $(shell grep 'MARKETING_VERSION:' $(PROJECT_YML) | sed 's/.*: *//')

all: build

project:
	xcodegen generate

build:
	xcodegen generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) build

release:
	xcodegen generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release build

run: build
	.build/debug/DuoduoManager

run-release: release
	.build/release/DuoduoManager

clean:
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
	@if [ -z "$(NEW_VERSION)" ] || [ "$(NEW_VERSION)" = "$(VERSION)" ]; then \
		echo "Usage: make update-version NEW_VERSION=x.x.x"; \
		exit 1; \
	fi
	sed -i '' 's/MARKETING_VERSION: .*/MARKETING_VERSION: $(NEW_VERSION)/' $(PROJECT_YML)
	xcodegen generate
	git add $(PROJECT_YML) $(APP_NAME).xcodeproj
	git commit -m "bump version to $(NEW_VERSION)"
	git tag -a v$(NEW_VERSION) -m "v$(NEW_VERSION)"
	git push origin main --tags
	@echo "Released v$(NEW_VERSION)"
