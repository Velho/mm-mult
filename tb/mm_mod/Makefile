# Project specific settings
PSRC ?=
RSRC ?= $(PWD)/../..

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

# VHDL_SOURCES += \
# 	$(PWD)/tb_mm_top.vhdl \
# 	$(PWD)/../hdl/mm_axi4lite.vhdl \
# 	$(PWD)/../hdl/mm_axi_addr.vhdl \
# 	$(PWD)/../hdl/mm_bram_ctrl.vhdl \
# 	$(PWD)/../hdl/pkg/mm_mod_pkg.vhdl \
# 	$(PWD)/../hdl/mm_mod.vhdl \
# 	$(PWD)/../hdl/stage/mm_pipe_load.vhdl

VHDL_SOURCES += \
				$(PWD)/tb_mm_mod.vhdl \
				$(RSRC)/hdl/mm_mod.vhdl \
				$(RSRC)/hdl/stage/mm_mult_stage.vhdl \
				$(RSRC)/hdl/pkg/mm_mod_pkg.vhdl



TOPLEVEL = tb_mm_mod
MODULE = tb_mm_mod

EXTRA_ARGS = -fsynopsys -fexplicit --std=08
SIM_ARGS ?= --wave=waveform.ghw

include $(shell cocotb-config --makefiles)/Makefile.sim

