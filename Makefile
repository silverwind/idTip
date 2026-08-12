node_modules: package.json
	pnpm install
	@touch node_modules

.PHONY: lint
lint: node_modules
	command -v luacheck >/dev/null 2>&1 || luarocks install luacheck
	luacheck idTip.lua idTip_test.lua
	go run github.com/rhysd/actionlint/cmd/actionlint@v1
	pnpm exec tsgo

.PHONY: test
test:
	command -v luajit >/dev/null 2>&1 || brew install luajit
	luajit idTip_test.lua

.PHONY: coverage
coverage:
	luajit -e "require('luacov')" 2>/dev/null || luarocks --lua-version 5.1 install luacov
	eval "$$(luarocks --lua-version 5.1 path)" && luajit -lluacov idTip_test.lua
	@luacov
	@sed -n '/^Summary/,$$p' luacov.report.out
	@rm -f luacov.stats.out

.PHONY: changelog
changelog:
	@git log -1 --pretty=%B | tail -n +3 | head -c -1

.PHONY: toc
toc:
	bash toc.sh

.PHONY: update
update: update-js update-actions

.PHONY: update-js
update-js: node_modules
	pnpm exec updates -u -f package.json
	rm -rf node_modules pnpm-lock.yaml
	$(MAKE) node_modules

.PHONY: patch minor major
patch minor major: node_modules
	pnpm exec versions $@ idTip.toc

.PHONY: chmod
chmod:
	@find . -type d -depth 1 -exec chmod 0755 {} \;
	@find . ! -path '*.sh' -type f -depth 1 -exec chmod 0644 {} \;
	@find .github -type d -exec chmod 0755 {} \;
	@find .github -type f -exec chmod 0644 {} \;

.PHONY: update-actions
update-actions: node_modules
	pnpm exec updates -u -M actions
