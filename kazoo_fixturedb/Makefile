CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_fixturedb

all: compile

update_view_hashes_otp_26:
	@ERL_LIBS=$(DEPS_DIR):$(CORE_DIR):$(APPS_DIR) $(CWD)/scripts/update_fixture_view_hashes_otp_26.escript

include $(ROOT)/make/kz.mk
