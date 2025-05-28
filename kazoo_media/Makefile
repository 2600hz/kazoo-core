CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_media

all: compile prompt_langs

prompt_langs: 
	$(CWD)/scripts/import_prompt_langs.sh

include $(ROOT)/make/kz.mk
