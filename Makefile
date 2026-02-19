APP_NAME := BrowserProxy
BUNDLE := build/$(APP_NAME).app
BINARY := $(BUNDLE)/Contents/MacOS/$(APP_NAME)
INSTALL_DIR := /Applications
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
BUNDLE_ID := com.daviderel.browserproxy

.PHONY: build install restart uninstall set-default login-item clean

build:
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp resources/Info.plist $(BUNDLE)/Contents/
	@cp resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	CGO_ENABLED=1 go build -o $(BINARY) ./src
	@echo "Built $(BUNDLE)"

install: build
	@cp -R $(BUNDLE) $(INSTALL_DIR)/
	@$(LSREGISTER) -R -f $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Run 'make set-default' to set as default browser"

restart: install
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 1
	@open $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Restarted $(APP_NAME)"

uninstall:
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@$(LSREGISTER) -u $(INSTALL_DIR)/$(APP_NAME).app 2>/dev/null || true
	@echo "Uninstalled $(APP_NAME).app"

set-default:
	@which defaultbrowser > /dev/null 2>&1 || (echo "Install defaultbrowser first: brew install defaultbrowser" && exit 1)
	@defaultbrowser browserproxy
	@echo "Set $(APP_NAME) as default browser"

login-item:
	@osascript -e 'tell application "System Events" to make login item at end with properties {path:"$(INSTALL_DIR)/$(APP_NAME).app", hidden:true}'
	@echo "Added $(APP_NAME) to login items (starts hidden on login)"

clean:
	@rm -rf build/
	@echo "Cleaned build artifacts"
