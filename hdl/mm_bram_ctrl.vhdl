-- vim: noai:ts=2:sw=2
----------------------------------------------------------------------------------
-- Author: Velho
-- 
-- Module Name: mm_mult_top - rtl
-- Project Name: 
-- Description: 
--  Implements the control logic for the bram when 
--
-- Dependencies: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mm_bram_ctrl is
  generic
  (
    C_S_BRAM_ADDR_WIDTH : integer := 32;
    C_S_BRAM_DATA_WIDTH : integer := 64;
    C_S_BRAM_WE_WIDTH   : integer := 8
  );
  port
  (
    CLK  : in std_logic; -- sys clock
    NRST : in std_logic; -- sys reset

    -- BRAM interface
    S_BRAM_ADDR   : out std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
    S_BRAM_CLK    : out std_logic;
    S_BRAM_WRDATA : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
    S_BRAM_RDDATA : in std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
    S_BRAM_EN     : out std_logic;
    S_BRAM_RST    : out std_logic;
    S_BRAM_WE     : out std_logic_vector(C_S_BRAM_WE_WIDTH - 1 downto 0);

    -- Control interface
    -- user passes the register which we want to be read
    -- todo(ja): diff between read and write at some point
    S_CTRL_ADDRESS  : in std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
    S_CTRL_REQ_READ : in std_logic;
    S_CTRL_RD_DATA  : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
    S_CTRL_DONE     : out std_logic;
    S_CTRL_DEBUG    : out std_logic_vector(7 downto 0);
    S_CTRL_BUSY     : out std_logic;
    S_DEBUG_4       : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of mm_bram_ctrl is

  constant primitive_output_en : boolean := true;

  signal clock_en : std_logic;
  signal b_reset  : std_logic;
  signal addr_set : std_logic;
  signal bram_rst : std_logic;

  signal read_addr : std_logic_vector (C_S_BRAM_ADDR_WIDTH - 1 downto 0);
  signal bram_en   : std_logic;

  signal bram_data     : std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
  signal rd_data_avail : std_logic;
  signal read_done     : std_logic;

  -- control signals for read latency
  constant READ_LATENCY   : integer := 2;
  signal latency_counter  : integer;
  signal latency_done      : std_logic; -- latency counter exhausted

begin
  -- bram controller functionality
  -- 1. add support for reading the bram from the given address
  -- 1.1. user writes the bram address to CTRL_ADDRESS
  -- 1.2. read operation should start with the REQ_READ
  -- 1.3. clock should be generated at this point or should be running already
  -- 1.4. after clock has been generated, assert the reset and proceed with the opferation
  -- 2. latch address
  -- 3. latch data

  -- fixme(ja): there's some sort of feedback issue where the bram reading is performed multiple times...
  -- requires some sort of busy flag ?
  -- fixme(ja): configuration flag to enable and disable if PRIMITIVE OUTPUT REGISTERS option for the bram is used
  -- this should disable the extra clock needed to sample the bram

  S_BRAM_RST <= bram_rst;
  S_BRAM_CLK <= CLK; -- when clock_en = '1' else '0';
  S_BRAM_ADDR <= read_addr;
  S_BRAM_EN <= bram_en;

  S_DEBUG_4 <= S_BRAM_RDDATA;

  -- TODO(ja):
  --  bram data is available for read operation when the rd_data_avail is asserted
  --  done could be perhaps written from the rd_data_avail instead of read_done.
  --  this should result of samping RD_DATA one clock earlier.
  S_CTRL_DONE    <= read_done;
  S_CTRL_RD_DATA <= bram_data;

  -- S_CTRL_BUSY <= '1' when (clock_en = '1' or S_CTRL_REQ_READ = '1') and read_done = '0' else '0';
  S_CTRL_BUSY <= (clock_en or S_CTRL_REQ_READ) and not read_done;
  -- print the counter always, not just when it is enabled
  -- when read_enabled = '1' 
  -- else ( others => '0' );

  -- counter simulates the bram reading operation
  -- the logic here is to test out if the control signals work
  -- before actually committingto the implementation of the controller
  -- itself.

  -- process bram_state
  --
  -- IN: S_CTRL_REQ_READ - read request from the port signal
  -- enables the bram clock from the read request. after the clock
  -- has been started bram is enabled.
  -- bram clock and enable signals are deassrted when 
  p_bram_state : process (CLK, NRST, S_CTRL_REQ_READ, clock_en, rd_data_avail)
  begin
    if NRST = '0' then
      clock_en  <= '0';
      b_reset   <= '0';
      bram_rst  <= '0';
      bram_en   <= '0';
      read_done <= '0';
      addr_set  <= '0';
      read_addr <= ( others => '0' );
    elsif rising_edge (CLK) then
      -- read request received
      if S_CTRL_REQ_READ = '1' then
        clock_en  <= '1';
        bram_rst  <= '1';
        read_done <= '0';
      end if;

      -- if bram_rst = '1' then
      --   bram_rst <= '0';
      -- end if;

        -- clock started, enable bram and drive the address
      if clock_en = '1' then
        bram_rst <= '0';
        bram_en <= '1';
        read_addr <= S_CTRL_ADDRESS;
        addr_set  <= '1';
      end if;

      if rd_data_avail = '1' then
        bram_en   <= '0';
        read_done <= '1';
        clock_en  <= '0';
      end if;

      if read_done = '1' then
        addr_set <= '0';
        read_done <= '0';
      end if;
    end if;
  end process;

  -- bram read latency
  -- IN: bram_en - bram enabled
  --
  -- implements the specific read latency defined by the 
  -- xilinx block memory generator. latency can be read from
  -- the block memory generator summary.
  -- takes into account the clock cycle it takes to start the
  -- counter so subtract from the constant.
  -- todo(ja): perhaps counter could be generic input for the controller ?
  p_latency_counter : process (CLK, NRST, bram_en)
  begin
    if NRST = '0' then
      latency_done <= '0';
      latency_counter <= 0;
    elsif rising_edge (CLK) then

      -- FIXME(ja): condition seems little wrong but it works
      -- basically when the latency has been exhausted and bram is still
      -- enabled, latency exhaust shouldn't be set to 0

      -- it takes 1 clock cycle to start the latency counter so
      -- count until - 1 from the latency constant so we can sample
      -- data one clock cycle after the latency counter is done
      if bram_en = '1' then
        if latency_done = '1' then
          latency_counter <= 0;
        elsif latency_counter = READ_LATENCY-1 then
          latency_done <= '1';
        else
          latency_counter <= latency_counter + 1;
        end if;
      else
        latency_counter <= 0;
        latency_done <= '0';
      end if;
    end if;
  end process;

  p_read_bram : process (CLK, NRST, S_BRAM_RDDATA, addr_set, read_done, latency_done)
  begin
    if NRST = '0' then
      bram_data     <= (others => '0');
      rd_data_avail <= '0';
    elsif rising_edge (CLK) then
      -- sample the read data when address has been set and primitive delay has been exhausted
      if addr_set = '1' and latency_done = '1' then
        rd_data_avail <= '1';
        bram_data     <= S_BRAM_RDDATA; --latch the data
      end if;

      if read_done = '1' then
        rd_data_avail <= '0';
      end if;
    end if; -- NRST
  end process;

end rtl;
