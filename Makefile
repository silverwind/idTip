node_modules: package.json
	npm install --no-save
	@touch node_modules

.PHONY: test
test: node_modules
	npx vitest

.PHONY: changelog
changelog:
	@git log -1 --pretty=%B | head -c -1

.PHONY: zip
zip:
	rm -rf idTip
	mkdir -p idTip
	cp idTip.lua idTip.toc idTip
	zip idTip-$(shell git describe --abbrev=0).zip idTip
	rm -rf idTip

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
