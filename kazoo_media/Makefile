CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_media

PROMPT_EN-US = priv/prompts/kazoo/en-us.txt
FS_EN-US = priv/prompts/freeswitch/en-us.xml

COMPILE_MOAR = assets

all: compile assets

assets: $(PROMPT_EN-US) \
	 $(FS_EN-US)

$(PROMPT_EN-US):
	@mkdir -p $(shell dirname $(PROMPT_EN-US))
	wget -qO $@ https://raw.githubusercontent.com/2600hz/kazoo-sounds/refs/heads/master/kazoo-core/en/us/prompts.txt

$(FS_EN-US):
	@mkdir -p $(shell dirname $(FS_EN-US))
	wget -qO $@ https://raw.githubusercontent.com/2600hz/kazoo-sounds/refs/heads/master/freeswitch/en/us/prompts.xml

include $(ROOT)/make/kz.mk
