LIBDIR := lib
-include $(LIBDIR)/main.mk

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

$(CDDL_COMBINED): $(CDDL_SOURCE_FILES)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(foreach f,$^,cat $(f) >> $@; echo >> $@;)

draft-ietf-asdf-sdf-protocol-mapping.xml: $(CDDL_COMBINED)

clean:: ; -rm -rf $(GENERATED_DIR)
