zip:
	$(eval VER := $(shell jq .version package.json))
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip

patch:
	npx ver patch idTip.toc
	$(MAKE) zip

minor:
	npx ver minor idTip.toc
	$(MAKE) zip

major:
	npx ver major idTip.toc
	$(MAKE) zip

.PHONY: zip patch minor major

