node_modules: pnpm-lock.yaml
	pnpm install
	@touch node_modules

.PHONY: deps
deps: node_modules

.PHONY: lint
lint: node_modules
	command -v luacheck >/dev/null 2>&1 || luarocks install luacheck
	luacheck idTip.lua idTip_test.lua
	go run github.com/rhysd/actionlint/cmd/actionlint@v1
	pnpm exec tsgo

.PHONY: lint-fix
lint-fix: lint

.PHONY: test
test: node_modules
	command -v luajit >/dev/null 2>&1 || brew install luajit
	luajit idTip_test.lua
	@$(MAKE) --no-print-directory chmod

.PHONY: test-coverage
test-coverage: node_modules
	luajit -e "require('luacov')" 2>/dev/null || luarocks --lua-version 5.1 install luacov
	eval "$$(luarocks --lua-version 5.1 path)" && luajit -lluacov idTip_test.lua
	@luacov
	@sed -n '/^Summary/,$$p' luacov.report.out
	@rm -f luacov.stats.out

.PHONY: build
build: node_modules

.PHONY: update
update: update-js update-actions

.PHONY: update-js
update-js: node_modules
	pnpm exec updates -u -f package.json
	rm -rf node_modules pnpm-lock.yaml
	pnpm install
	@touch node_modules

.PHONY: update-actions
update-actions: node_modules
	pnpm exec updates -u -M actions

.PHONY: patch minor major
patch minor major: node_modules
	pnpm exec versions $@ idTip.toc

.PHONY: changelog
changelog:
	@git log -1 --pretty=%B | tail -n +3 | head -c -1

.PHONY: toc
toc:
	bash toc.sh

# Blizzard's Agent chmods 0777 across its AddOns tree, which reaches idTip.lua and
# idTip.toc through the symlinks there, so normalize before they reach a commit.
# Link only those two files into AddOns, never this directory, or the sweep also
# walks .git and node_modules and the launcher hangs on "Initializing".
.PHONY: chmod
chmod:
	@find . -mindepth 1 -maxdepth 1 -type d -exec chmod 0755 {} \;
	@find . -mindepth 1 -maxdepth 1 ! -path '*.sh' -type f -exec chmod 0644 {} \;
	@find .github -type d -exec chmod 0755 {} \;
	@find .github -type f -exec chmod 0644 {} \;
