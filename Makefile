# os dependencies: git grep zip sed
# npm dependencies: semver

VERSION := $(shell egrep -o "[0-9]+\.[0-9]+\.[0-9]+" idTip.toc)
VPATCH := $$(semver -i patch $(VERSION))
VMINOR := $$(semver -i minor $(VERSION))
VMAJOR := $$(semver -i major $(VERSION))

patch:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VPATCH)/" > idTip.toc
	mkdir idTip && cp idTip.lua idTip.toc README.md idTip && \
	      zip idTip-$(VPATCH).zip idTip/idTip.lua idTip/idTip.toc idTip/README.md; rm -r idTip
	git commit -am $(VPATCH)
	git tag -a $(VPATCH) -m $(VPATCH)

minor:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VMINOR)/" > idTip.toc
	mkdir idTip && cp idTip.lua idTip.toc README.md idTip && \
	      zip idTip-$(VMINOR).zip idTip/idTip.lua idTip/idTip.toc idTip/README.md; rm -r idTip
	git commit -am $(VMINOR)
	git tag -a $(VMINOR) -m $(VMINOR)

major:
	cat idTip.toc | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+/$(VMINOR)/" > idTip.toc
	mkdir idTip && cp idTip.lua idTip.toc README.md idTip && \
	      zip idTip-$(VMINOR).zip idTip/idTip.lua idTip/idTip.toc idTip/README.md; rm -r idTip
	git commit -am $(VMINOR)
	git tag -a $(VMINOR) -m $(VMINOR)

.PHONY: patch minor major

