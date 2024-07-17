import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb import start_soon

@cocotb.test()
async def test_mm_mod(dut):
    clock = Clock(dut.CLK, 2, units="ns")
    start_soon(clock.start(start_high=False))

    # testing out the mm_mod
    dut.op_a_address.value = 0x42

    await ClockCycles(dut.CLK, 5)

