-- fifo instantiation wrapper for the xilinx ip
-- velho@2024

library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;

entity fifo is
  generic
  (
    C_FIFO_DATA_WIDTH : integer := 64;
    C_FIFO_DATA_DEPTH : integer := 8
  );
  port
  (
    CLK   : in std_logic;
    NRST  : in std_logic;
    EN    : in std_logic;
    DIN   : in std_logic_vector (C_FIFO_DATA_WIDTH - 1 downto 0);
    DOUT  : out std_logic_vector (C_FIFO_DATA_WIDTH - 1 downto 0);
    EMPTY : out std_logic;
    FULL  : out std_logic
  );
end fifo;

architecture rtl of fifo is

begin

  -- source: https://docs.amd.com/r/2021.1-English/ug974-vivado-ultrascale-libraries/FIFO36E2
  -- FIFO36E2: 36Kb FIFO (First-In-First-Out) Block RAM Memory
  --           UltraScale
  -- Xilinx HDL Language Template, version 2024.1

  FIFO36E2_inst : FIFO36E2
  generic
  map (
      CASCADE_ORDER           => "NONE", -- FIRST, LAST, MIDDLE, NONE, PARALLEL
      CLOCK_DOMAINS           => "INDEPENDENT", -- COMMON, INDEPENDENT
      EN_ECC_PIPE             => "FALSE", -- ECC pipeline register, (FALSE, TRUE)
      EN_ECC_READ             => "FALSE", -- Enable ECC decoder, (FALSE, TRUE)
      EN_ECC_WRITE            => "FALSE", -- Enable ECC encoder, (FALSE, TRUE)
      FIRST_WORD_FALL_THROUGH => "FALSE", -- FALSE, TRUE
      INIT                    => X"000000000000000000", -- Initial values on output port
      PROG_EMPTY_THRESH       => 256, -- Programmable Empty Threshold
      PROG_FULL_THRESH        => 256, -- Programmable Full Threshold
      -- Programmable Inversion Attributes: Specifies the use of the built-in programmable inversion
      IS_RDCLK_INVERTED  => '0', -- Optional inversion for RDCLK
      IS_RDEN_INVERTED   => '0', -- Optional inversion for RDEN
      IS_RSTREG_INVERTED => '0', -- Optional inversion for RSTREG
      IS_RST_INVERTED    => '1', -- Optional inversion for RST
      IS_WRCLK_INVERTED  => '0', -- Optional inversion for WRCLK
      IS_WREN_INVERTED   => '0', -- Optional inversion for WREN
      RDCOUNT_TYPE       => "RAW_PNTR", -- EXTENDED_DATACOUNT, RAW_PNTR, SIMPLE_DATACOUNT, SYNC_PNTR
      READ_WIDTH         => 4, -- 18-9
      REGISTER_MODE      => "UNREGISTERED", -- DO_PIPELINED, REGISTERED, UNREGISTERED
      RSTREG_PRIORITY    => "RSTREG", -- REGCE, RSTREG
      SLEEP_ASYNC        => "FALSE", -- FALSE, TRUE
      SRVAL              => X"000000000000000000", -- SET/reset value of the FIFO outputs
      WRCOUNT_TYPE       => "RAW_PNTR", -- EXTENDED_DATACOUNT, RAW_PNTR, SIMPLE_DATACOUNT, SYNC_PNTR
      WRITE_WIDTH        => 4 -- 18-9
  )
  port map
  (
    -- Cascade Signals outputs: Multi-FIFO cascade signals
    CASDOUT     => open, -- 64-bit output: Data cascade output bus
    CASDOUTP    => open, -- 8-bit output: Parity data cascade output bus
    CASNXTEMPTY => open, -- 1-bit output: Cascade next empty
    CASPRVRDEN  => open, -- 1-bit output: Cascade previous read enable
    -- ECC Signals outputs: Error Correction Circuitry ports
    DBITERR   => open, -- 1-bit output: Double bit error status
    ECCPARITY => open, -- 8-bit output: Generated error correction parity
    SBITERR   => open, -- 1-bit output: Single bit error status
    -- Read Data outputs: Read output data
    DOUT  => DOUT, -- 64-bit output: FIFO data output bus
    DOUTP => open, -- 8-bit output: FIFO parity output bus.
    -- Status outputs: Flags and other FIFO status outputs
    EMPTY     => EMPTY, -- 1-bit output: Empty
    FULL      => FULL, -- 1-bit output: Full
    PROGEMPTY => open, -- 1-bit output: Programmable empty
    PROGFULL  => open, -- 1-bit output: Programmable full
    RDCOUNT   => open, -- 14-bit output: Read count
    RDERR     => open, -- 1-bit output: Read error
    RDRSTBUSY => open, -- 1-bit output: Reset busy (sync to RDCLK)
    WRCOUNT   => open, -- 14-bit output: Write count
    WRERR     => open, -- 1-bit output: Write Error
    WRRSTBUSY => open, -- 1-bit output: Reset busy (sync to WRCLK)
    -- Cascade Signals inputs: Multi-FIFO cascade signals
    CASDIN        => open, -- 64-bit input: Data cascade input bus
    CASDINP       => open, -- 8-bit input: Parity data cascade input bus
    CASDOMUX      => open, -- 1-bit input: Cascade MUX select input
    CASDOMUXEN    => open, -- 1-bit input: Enable for cascade MUX select
    CASNXTRDEN    => open, -- 1-bit input: Cascade next read enable
    CASOREGIMUX   => open, -- 1-bit input: Cascade output MUX select
    CASOREGIMUXEN => open, -- 1-bit input: Cascade output MUX select enable
    CASPRVEMPTY   => open, -- 1-bit input: Cascade previous empty
    -- ECC Signals inputs: Error Correction Circuitry ports
    INJECTDBITERR => open, -- 1-bit input: Inject a double-bit error
    INJECTSBITERR => open, -- 1-bit input: Inject a single bit error
    -- Read Control Signals inputs: Read clock, enable and reset input signals
    RDCLK  => CLK, -- 1-bit input: Read clock
    RDEN   => EN, -- 1-bit input: Read enable
    REGCE  => open, -- 1-bit input: Output register clock enable
    RSTREG => open, -- 1-bit input: Output register reset
    SLEEP  => open, -- 1-bit input: Sleep Mode
    -- Write Control Signals inputs: Write clock and enable input signals
    RST   => NRST, -- 1-bit input: Reset
    WRCLK => open, -- 1-bit input: Write clock
    WREN  => open, -- 1-bit input: Write enable
    -- Write Data inputs: Write input data
    DIN  => DIN, -- 64-bit input: FIFO data input bus
    DINP => open -- 8-bit input: FIFO parity input bus
  );

  -- End of FIFO36E2_inst instantiation

end rtl;