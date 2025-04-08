CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_data
COMPILE_MOAR = ebin/kz_data.beam
SOURCES = $(wildcard src/*.erl) $(wildcard src/*/*.erl)

ERLC_OPTS += +'{lager_extra_sinks, [data]}'

all: compile

-include $(ROOT)/make/kz.mk
