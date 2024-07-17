# Top-level makefile to simulate the modules in
# different subdirectories. Different test for each
# vhdl entity can be found from it's own subdir.
# velho @ 2024

# Root project source
RSRC = $(PWD)/..
# Testbench folder
PSRC = $(PWD)

SUBDIRS = mm_axi mm_mod

.PHONY: all $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@ RSRC=$(RSRC) PSRC=$(PSRC)


clean:
	@for d in $(SUBDIRS) ; do \
		$(MAKE) -C $$d clean; \
	done
