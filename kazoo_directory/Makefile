CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/../..)
PROJECT = kazoo_directory

COMPILE_MOAR = ebin/kz_directory_device_spec.beam
SOURCES = $(wildcard src/*.erl)

all: compile

include $(ROOT)/make/kz.mk
