CWD = $(shell pwd -P)
ROOT ?= $(realpath $(CWD)/..)
MS = $(sort $(wildcard */Makefile))
MAKEDIRS ?= $(MS:/Makefile=)


.PHONY: all deps compile compile-test compile-test-direct clean clean-test eunit test first

all: compile

deps: ACTION = deps
deps: $(MAKEDIRS)

compile: ACTION = all
compile: $(MAKEDIRS)

compile-lean: ACTION = compile-lean
compile-lean: $(MAKEDIRS)

compile-test: ACTION = compile-test
compile-test: $(MAKEDIRS)

compile-test-direct: ACTION = compile-test-direct
compile-test-direct: $(MAKEDIRS)

clean: ACTION = clean
clean: $(MAKEDIRS)

clean-test: ACTION = clean-test
clean-test: $(MAKEDIRS)

eunit: ACTION = eunit
eunit: $(MAKEDIRS)

test: ACTION = test
test: $(MAKEDIRS)

first:
	@ROOT=$(ROOT) $(MAKE) -j1 -C kazoo_stdlib/ $(ACTION)
	@ROOT=$(ROOT) $(MAKE) -j1 -C kazoo_amqp/ $(ACTION)
	@ROOT=$(ROOT) $(MAKE) -j1 -C kazoo_data/ $(ACTION)

.PHONY: $(MAKEDIRS)
$(MAKEDIRS): first
	@ROOT=$(ROOT) $(MAKE) -C $(ROOT)/core/$@ $(ACTION)
