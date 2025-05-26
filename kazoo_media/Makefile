CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_media

PROMPT_DIR = priv/prompts/kazoo
PROMPT_DE-DE = $(PROMPT_DIR)/de-de.txt
PROMPT_EN-US = $(PROMPT_DIR)/en-us.txt
PROMPT_EN-GB = $(PROMPT_DIR)/en-gb.txt
PROMPT_ES-ES = $(PROMPT_DIR)/es-es.txt
PROMPT_ES-US = $(PROMPT_DIR)/es-us.txt
PROMPT_FR-CA = $(PROMPT_DIR)/fr-ca.txt
PROMPT_FR-FR = $(PROMPT_DIR)/fr-fr.txt
PROMPT_NL-BE = $(PROMPT_DIR)/nl-be.txt
PROMPT_RU-RU = $(PROMPT_DIR)/ru-ru.txt

FS_PROM_DIR = priv/prompts/freeswitch
FS_PROM_DE-DE = $(FS_PROM_DIR)/de-de.xml
FS_PROM_EN-US = $(FS_PROM_DIR)/en-us.xml
FS_PROM_EN-GB = $(FS_PROM_DIR)/en-gb.xml
FS_PROM_ES-ES = $(FS_PROM_DIR)/es-es.xml
FS_PROM_ES-US = $(FS_PROM_DIR)/es-us.xml
FS_PROM_FR-CA = $(FS_PROM_DIR)/fr-ca.xml
FS_PROM_FR-FR = $(FS_PROM_DIR)/fr-fr.xml
FS_PROM_NL-BE = $(FS_PROM_DIR)/nl-be.xml
FS_PROM_RU-RU = $(FS_PROM_DIR)/ru-ru.xml

KAZOO_GIT_URL = https://raw.githubusercontent.com/2600hz/kazoo-sounds/refs/heads/master/kazoo-core
FS_GIT_URL = https://raw.githubusercontent.com/2600hz/kazoo-sounds/refs/heads/master/freeswitch

COMPILE_MOAR = assets

all: compile assets

assets: $(PROMPT_DE-DE) \
        $(PROMPT_EN-US) \
        $(PROMPT_EN-GB) \
        $(PROMPT_ES-ES) \
        $(PROMPT_ES-US) \
        $(PROMPT_FR-CA) \
        $(PROMPT_FR-FR) \
        $(PROMPT_NL-BE) \
        $(PROMPT_RU-RU) \
        $(FS_PROM_DE-DE) \
        $(FS_PROM_EN-US) \
        $(FS_PROM_EN-GB) \
        $(FS_PROM_ES-ES) \
        $(FS_PROM_ES-US) \
        $(FS_PROM_FR-CA) \
        $(FS_PROM_FR-FR) \
        $(FS_PROM_NL-BE) 

$(PROMPT_DE-DE):
	@mkdir -p $(shell dirname $(PROMPT_DE-DE))
	wget -qO $@ $(KAZOO_GIT_URL)/de/de/prompts.txt

$(PROMPT_EN-US):
	@mkdir -p $(shell dirname $(PROMPT_EN-US))
	wget -qO $@ $(KAZOO_GIT_URL)/en/us/prompts.txt

$(PROMPT_EN-GB):
	@mkdir -p $(shell dirname $(PROMPT_EN-GB))
	wget -qO $@ $(KAZOO_GIT_URL)/en/gb/prompts.txt

$(PROMPT_ES-ES):
	@mkdir -p $(shell dirname $(PROMPT_ES-ES))
	wget -qO $@ $(KAZOO_GIT_URL)/es/es/prompts.txt

$(PROMPT_ES-US):
	@mkdir -p $(shell dirname $(PROMPT_ES-US))
	wget -qO $@ $(KAZOO_GIT_URL)/es/us/prompts.txt

$(PROMPT_FR-CA):
	@mkdir -p $(shell dirname $(PROMPT_FR-CA))
	wget -qO $@ $(KAZOO_GIT_URL)/fr/ca/prompts.txt

$(PROMPT_FR-FR):
	@mkdir -p $(shell dirname $(PROMPT_FR-FR))
	wget -qO $@ $(KAZOO_GIT_URL)/fr/fr/prompts.txt

$(PROMPT_NL-BE):
	@mkdir -p $(shell dirname $(PROMPT_NL-BE))
	wget -qO $@ $(KAZOO_GIT_URL)/nl/be/prompts.txt

$(PROMPT_RU-RU):
	@mkdir -p $(shell dirname $(PROMPT_RU-RU))
	wget -qO $@ $(KAZOO_GIT_URL)/ru/ru/prompts.txt

$(FS_PROM_DE-DE):
	@mkdir -p $(shell dirname $(FS_PROM_DE-DE))
	wget -qO $@ $(FS_GIT_URL)/de/de/prompts.xml

$(FS_PROM_EN-US):
	@mkdir -p $(shell dirname $(FS_PROM_EN-US))
	wget -qO $@ $(FS_GIT_URL)/en/us/prompts.xml

$(FS_PROM_EN-GB):
	@mkdir -p $(shell dirname $(FS_PROM_EN-GB))
	wget -qO $@ $(FS_GIT_URL)/en/gb/prompts.xml

$(FS_PROM_ES-ES):
	@mkdir -p $(shell dirname $(FS_PROM_ES-ES))
	wget -qO $@ $(FS_GIT_URL)/es/es/prompts.xml

$(FS_PROM_ES-US):
	@mkdir -p $(shell dirname $(FS_PROM_ES-US))
	wget -qO $@ $(FS_GIT_URL)/es/us/prompts.xml

$(FS_PROM_FR-CA):
	@mkdir -p $(shell dirname $(FS_PROM_FR-CA))
	wget -qO $@ $(FS_GIT_URL)/fr/ca/prompts.xml

$(FS_PROM_FR-FR):
	@mkdir -p $(shell dirname $(FS_PROM_FR-FR))
	wget -qO $@ $(FS_GIT_URL)/fr/fr/prompts.xml

$(FS_PROM_NL-BE):
	@mkdir -p $(shell dirname $(FS_PROM_NL-BE))
	wget -qO $@ $(FS_GIT_URL)/nl/BE/prompts.xml

include $(ROOT)/make/kz.mk
