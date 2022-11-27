node_modules: package.json
	npm install --no-save
	@touch node_modules

.PHONY: zip
zip:
	rm -rf idTip
	mkdir -p idTip
	cp idTip.lua idTip.toc idTip
	zip idTip-$(shell git describe --abbrev=0).zip idTip
	rm -rf idTip

.PHONY: patch
patch: node_modules
	npx versions patch idTip.toc

.PHONY: minor
minor: node_modules
	npx versions minor idTip.toc

.PHONY: major
major: node_modules
	npx versions major idTip.toc
