.PHONY: bootstrap open build clean backend-install backend-dev help

help:
	@echo "PalmMate — common tasks"
	@echo ""
	@echo "  make bootstrap     Install deps, copy Config.xcconfig, generate .xcodeproj"
	@echo "  make open          Bootstrap and open the project in Xcode"
	@echo "  make build         Headless simulator build (sanity check, no signing)"
	@echo "  make clean         Remove generated Xcode project + DerivedData artifacts"
	@echo ""
	@echo "  make backend-install   Install the Cloudflare Worker dependencies"
	@echo "  make backend-dev       Run the Worker locally (wrangler dev)"

bootstrap:
	@./bootstrap.sh

open:
	@./bootstrap.sh --open

build:
	cd PalmMate && xcodebuild \
		-project PalmMate.xcodeproj \
		-scheme PalmMate \
		-destination "generic/platform=iOS Simulator" \
		-configuration Debug \
		-sdk iphonesimulator \
		CODE_SIGNING_ALLOWED=NO \
		build

clean:
	rm -rf PalmMate/PalmMate.xcodeproj
	rm -rf PalmMate/build
	@echo "Cleaned. Run 'make bootstrap' to regenerate."

backend-install:
	cd backend && npm install

backend-dev:
	cd backend && npm run dev
