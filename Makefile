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

GENERATED_DIR= generated

CDDL_SOURCE_FILES= cddl/sdf-property-protocol-map.cddl \
	cddl/sdf-action-protocol-map.cddl \
	cddl/sdf-event-protocol-map.cddl \
	cddl/ble-protocol-map.cddl \
	cddl/ble-event-map.cddl \
	cddl/zigbee-protocol-map.cddl \
	cddl/zigbee-event-map.cddl \
	cddl/zigbee-action-map.cddl
CDDL_COMBINED= $(GENERATED_DIR)/combined.cddl

JSON_SOURCE_FILES= scim/scim-sdf-extension.json
YAML_SOURCE_FILES= $(wildcard openapi/*.yaml)

SOURCE_FOLDED= $(addprefix $(GENERATED_DIR)/,$(JSON_SOURCE_FILES:.json=.json.folded) $(YAML_SOURCE_FILES:.yaml=.yaml.folded) $(CDDL_SOURCE_FILES:.cddl=.cddl.folded)) \
	$(CDDL_COMBINED:.cddl=.cddl.folded)

$(GENERATED_DIR)/%.json.folded: %.json rfcfold/rfcfold
	@mkdir -p $(dir $@)
	./rfcfold/rfcfold -i $< -o $@ || [ $$? -eq 255 ]

$(GENERATED_DIR)/%.yaml.folded: %.yaml rfcfold/rfcfold
	@mkdir -p $(dir $@)
	./rfcfold/rfcfold -i $< -o $@ || [ $$? -eq 255 ]

$(GENERATED_DIR)/%.cddl.folded: %.cddl rfcfold/rfcfold
	@mkdir -p $(dir $@)
	./rfcfold/rfcfold -i $< -o $@ || [ $$? -eq 255 ]

$(CDDL_COMBINED): $(CDDL_SOURCE_FILES)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(foreach f,$^,cat $(f) >> $@; echo >> $@;)

$(CDDL_COMBINED).folded: $(CDDL_COMBINED) rfcfold/rfcfold
	./rfcfold/rfcfold -i $< -o $@ || [ $$? -eq 255 ]

draft-ietf-asdf-sdf-protocol-mapping.xml: rfcfold/rfcfold $(SOURCE_FOLDED)

.SECONDARY: draft-ietf-asdf-sdf-protocol-mapping.xml

clean:: ; -rm -rf $(GENERATED_DIR)
