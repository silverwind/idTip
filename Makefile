zip:
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip

patch:
	npx ver patch -c "make zip" idTip.toc

minor:
	npx ver minor -c "make zip" idTip.toc

major:
	npx ver major -c "make zip" idTip.toc

.PHONY: zip patch minor major

