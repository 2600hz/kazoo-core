CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_stdlib

LEX_SOURCES = $(wildcard src/*.[xy]rl)
LEX_FILES := $(sort $(foreach module,$(LEX_SOURCES),src/$(shell basename $(module) | cut -d. -f1).erl))

SOURCES = $(wildcard src/*.erl) $(wildcard src/*/*.erl) $(LEX_FILES)

all: compile

clean: lex-clean

compile: $(LEX_FILES)

lex-clean:
	@rm -f $(LEX_FILES)

$(LEX_FILES): $(LEX_SOURCES)
	@erlc -W0 -o src/ $?


include $(ROOT)/make/kz.mk
