import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb import start_soon

from cocotbext.axi import AxiLiteBus, AxiLiteMaster

@cocotb.test()
async def test_axi_write_1(dut):

    clock = Clock(dut.S_AXI_ACLK, 2, units="ns")
    start_soon(clock.start(start_high=False))

    axi_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.S_AXI_ACLK, dut.S_AXI_ARESETN, False)

    dut.S_AXI_ARESETN.value = 0
    await ClockCycles(dut.s_axi_aclk, 2)
    dut.S_AXI_ARESETN.value = 1

    dut.S_BRAM_RDDATA.value = 0x42

    # write x4 to 0x0 (REG0)
    # await axi_master.write(0x0, b'\x04')
    # await ClockCycles(dut.S_AXI_ACLK, 2)

    # # write xc to 0x0 (REG0)
    # # await axi_master.write(0x0, b'\x0c')
    # # await ClockCycles(dut.S_AXI_ACLK, 2)

    # # write x0 to CTRL register
    # await axi_master.write(0x48, b'\x00')
    # await ClockCycles(dut.S_AXI_ACLK, 2)

    # data = await axi_master.read(0xc, 1)
    # print(f"data={data}")
    await ClockCycles(dut.S_AXI_ACLK, 20)

