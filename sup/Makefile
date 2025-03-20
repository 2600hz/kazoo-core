CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = sup

ESCRIPT = $(CURDIR)/sup
CLEAN_MOAR = clean-escript
ZIP_CMD ?= zip  # unless 7z is available

DEPS = getopt zucchini lager

all: compile $(ESCRIPT) cleanup-after

$(PROJECT).d:: kz_stdlib

# copies necessary KAZOO beams
kz_stdlib:
	@cp $(CORE_DIR)/kazoo_stdlib/ebin/props.beam ebin/
	@cp $(CORE_DIR)/kazoo_stdlib/ebin/kz_binary.beam ebin/
	@cp $(CORE_DIR)/kazoo_stdlib/ebin/kz_term.beam ebin/
	@cp $(CORE_DIR)/kazoo_stdlib/ebin/kz_term.beam ebin/
	@cp $(CORE_DIR)/kazoo_stdlib/ebin/kz_network_utils.beam ebin/
	@cp $(CORE_DIR)/kazoo_config/ebin/kazoo_config_init.beam ebin/
	@cp $(CORE_DIR)/kazoo_config/ebin/kz_config.beam ebin/

app-build: compile

escript-list-runtime-deps:
	$(MAKE) -f $(ROOT)/erlang.mk escript-list-runtime-deps

clean-escript:
	@rm -f $(ESCRIPT)

escript: clean-escript $(ESCRIPT) cleanup-after

.PHONY: cleanup-after
cleanup-after:
	@rm -f ebin/props.beam
	@rm -f ebin/kz_binary.beam
	@rm -f ebin/kz_term.beam
	@rm -f ebin/kz_term.beam
	@rm -f ebin/kz_network_utils.beam
	@rm -f ebin/kazoo_config_init.beam
	@rm -f ebin/kz_config.beam

$(ESCRIPT): ebin/sup.beam
	$(MAKE) -f $(ROOT)/erlang.mk \
		DEPS_DIR="$(DEPS_DIR)" \
		DEPS="$(DEPS)" \
		ESCRIPT_ZIP=$(ZIP_CMD) \
		escript

include $(ROOT)/make/kz.mk
