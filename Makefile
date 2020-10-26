zip:
	$(eval VER := $(shell grep Version idTip.toc 2>/dev/null | cut -c 13-))
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip

patch:
	$(eval VER := $(shell grep Version idTip.toc 2>/dev/null | cut -c 13-))
	yarn -s run versions -b $(VER) -P patch idTip.toc
	$(MAKE) zip

minor:
	$(eval VER := $(shell grep Version idTip.toc 2>/dev/null | cut -c 13-))
	yarn -s run versions -b $(VER) -P minor idTip.toc
	$(MAKE) zip

major:
	$(eval VER := $(shell grep Version idTip.toc 2>/dev/null | cut -c 13-))
	yarn -s run versions -b $(VER) -P major idTip.toc
	$(MAKE) zip

.PHONY: zip patch minor major

