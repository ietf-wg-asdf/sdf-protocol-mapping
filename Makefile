LIBDIR := lib
include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

rfcfold/rfcfold:
	git submodule update --init rfcfold

SOURCE_FILES= scim/scim-sdf-extension.json

SOURCE_FOLDED= $(SOURCE_FILES:.json=.json.folded)

%.json.folded: %.json rfcfold/rfcfold
	./rfcfold/rfcfold -i $< -o $@ || [ $$? -eq 255 ]

draft-ietf-asdf-sdf-protocol-mapping.xml: rfcfold/rfcfold $(SOURCE_FOLDED)
