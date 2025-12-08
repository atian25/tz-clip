# Makefile

BUILD_DIR = .build
DEBUG_BIN = $(BUILD_DIR)/debug/TZClip
RELEASE_BIN = $(BUILD_DIR)/release/TZClip
ENTITLEMENTS = TZClip.entitlements

.PHONY: build run clean sign stop watch

build:
	swift build

run: build sign
	$(DEBUG_BIN)

sign:
	codesign --force --deep --sign - --entitlements $(ENTITLEMENTS) $(DEBUG_BIN)

clean:
	rm -rf $(BUILD_DIR)

stop:
	pkill -f TZClip || true

watch:
	./scripts/dev.sh
