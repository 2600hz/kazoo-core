CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_directory

SOURCES = $(wildcard src/kz_directory_device_spec.erl) $(wildcard src/*.erl)

all: compile

include $(ROOT)/make/kz.mk
