# os dependencies: git grep zip sed
VERSION := $(shell egrep -o "[0-9]+\.[0-9]+\.[0-9]+" idTip.toc)

patch:
	$(eval VER := $(shell npx semver -i patch $(VERSION)))
	sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VER)/" idTip.toc
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip
	git commit -am $(VER)
	git tag -a $(VER) -m $(VER)

minor:
	$(eval VER := $(shell npx semver -i minor $(VERSION)))
	sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VER)/" idTip.toc
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip
	git commit -am $(VER)
	git tag -a $(VER) -m $(VER)

major:
	$(eval VER := $(shell npx semver -i major $(VERSION)))
	sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VER)/" idTip.toc
	rm -rf zip/idTip
	mkdir -p zip/idTip
	cp idTip.lua idTip.toc README.md zip/idTip
	cd zip && zip idTip-$(VER).zip idTip/*
	rm -rf zip/idTip
	git commit -am $(VER)
	git tag -a $(VER) -m $(VER)

.PHONY: patch minor major

