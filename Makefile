# os dependencies: git grep zip sed
# npm dependencies: semver

VERSION := $(shell egrep -o "[0-9]+\.[0-9]+\.[0-9]+" idTip.toc)
VPATCH := $$(semver -i patch $(VERSION))
VMINOR := $$(semver -i minor $(VERSION))
VMAJOR := $$(semver -i major $(VERSION))

patch:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VPATCH)/" > idTip.toc
	git commit -am $(VPATCH)
	git tag -a $(VPATCH) -m $(VPATCH)
	zip idTip.zip idTip.lua idTip.toc README.md
	mv idTip.zip idTip-$(VPATCH).zip

minor:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VMINOR)/" > idTip.toc
	git commit -am $(VMINOR)
	git tag -a $(VMINOR) -m $(VMINOR)
	zip idTip.zip idTip.lua idTip.toc README.md
	mv idTip.zip idTip-$(VMINOR).zip

major:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VMINOR)/" > idTip.toc
	git commit -am $(VMINOR)
	git tag -a $(VMINOR) -m $(VMINOR)
	zip idTip.zip idTip.lua idTip.toc README.md
	mv idTip.zip idTip-$(VMINOR).zip

.PHONY: patch minor major

