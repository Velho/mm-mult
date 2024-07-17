
# Project specific settings
PSRC ?= 
RSRC ?= $(PWD)/../..

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += \
	$(PWD)/tb_mm_top.vhdl \
	$(RSRC)/hdl/mm_axi4lite.vhdl \
	$(RSRC)/hdl/mm_axi_addr.vhdl \
	$(RSRC)/hdl/mm_bram_ctrl.vhdl \
	$(RSRC)/hdl/pkg/mm_mod_pkg.vhdl \
	$(RSRC)/hdl/mm_mod.vhdl \
	$(RSRC)/hdl/stage/mm_pipe_load.vhdl



TOPLEVEL = mm_mult
MODULE = tb_mm

EXTRA_ARGS = -fsynopsys -fexplicit --std=08
SIM_ARGS ?= --wave=waveform.ghw

include $(shell cocotb-config --makefiles)/Makefile.sim

