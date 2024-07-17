
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

VHDL_SOURCES += $(PWD)../../hdl/mm_mod.vhdl


TOPLEVEL = mm_mult
MODULE = tb_mm

EXTRA_ARGS = -fsynopsys -fexplicit --std=08
SIM_ARGS ?= --wave=waveform.ghw

include $(shell cocotb-config --makefiles)/Makefile.sim

