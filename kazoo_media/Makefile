CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_media

PROMPT_DIR = priv/prompts/kazoo/

all: compile $(PROMPT_DIR)

$(PROMPT_DIR):
	@$(CWD)/scripts/import_prompt_langs.sh

prompt_langs:
	@$(CWD)/scripts/import_prompt_langs.sh

include $(ROOT)/make/kz.mk
