node_modules: package.json
	npm install --no-save
	@touch node_modules

.PHONY: lint
lint: node_modules
	luarocks show luacheck >/dev/null || luarocks install luacheck
	luacheck idTip.lua
	go run github.com/rhysd/actionlint/cmd/actionlint@v1
	npx tsgo

.PHONY: test
test: node_modules
	npx vitest

.PHONY: changelog
changelog:
	@git log -1 --pretty=%B | tail -n +3 | head -c -1

.PHONY: toc
toc:
	bash toc.sh

.PHONY: update
update: node_modules
	npx updates -cu
	rm -rf node_modules package-lock.json
	npm install
	@touch node_modules

.PHONY: patch
patch: node_modules
	npx versions patch idTip.toc

.PHONY: minor
minor: node_modules
	npx versions minor idTip.toc

.PHONY: major
major: node_modules
	npx versions major idTip.toc

.PHONY: chmod
chmod:
	@find . -type d -depth 1 -exec chmod 0755 {} \;
	@find . ! -path '*.sh' -type f -depth 1 -exec chmod 0644 {} \;
	@find .github -type d -exec chmod 0755 {} \;
	@find .github -type f -exec chmod 0644 {} \;
