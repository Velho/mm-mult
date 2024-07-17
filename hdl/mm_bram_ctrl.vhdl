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

  -- primitives output register generated for the bram
  -- requires the clock to be stalled by one cycle before
  -- sampling the output
  signal primitive_out    : std_logic;
  signal primitive_delay  : std_logic;

  constant READ_LATENCY   : integer := 2;
  signal latency_counter  : integer;
  signal latecy_exh : std_logic;

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

  S_BRAM_RST <= '0';
  S_BRAM_CLK <= CLK; -- when clock_en = '1' else '0';
  S_BRAM_ADDR <= read_addr when addr_set = '1' else
    (others => '0');
  S_BRAM_EN <= '1' when bram_en = '1' else '0';

  S_DEBUG_4 <= S_BRAM_RDDATA;

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
    else
      if rising_edge (CLK) then
        -- read request received
        if S_CTRL_REQ_READ = '1' then
          clock_en  <= '1';
          read_done <= '0';
        end if;

        -- clock started, enable bram
        if clock_en = '1' then
          bram_en <= '1';
        end if;

        if rd_data_avail = '1' then
          bram_en   <= '0';
          read_done <= '1';
          clock_en  <= '0';
        end if;

      end if;
    end if;
  end process;

  p_latency: process (CLK, NRST)
  begin
    if NRST = '0' then
      latency_counter <= 0;
    else

      -- if rising_edge (CLK) then
      --   if bram_en = '1' then
      --     latency_counter <= 0;
      --   elsif latency_counter = READ_LATENCY then
      --     latency_counter <= latency_counter + 1;
      --   else
      --   end if;
      -- end if;

    end if;
  end process;

  -- todo: replace this primitve output register delay with counter
  -- delays the sampling by one clock
  p_primitive_out : process (CLK, NRST, addr_set, primitive_out, read_done)
  begin
    if NRST = '0' then
      primitive_out <= '0';
      primitive_delay <= '0';
    else
      if rising_edge (CLK) then
        if primitive_out = '1' then
          primitive_out <= '0';
        elsif addr_set = '1' and primitive_delay = '0' then
          primitive_out <= '1';
          primitive_delay <= '1';
        end if;

        -- reset flops after read_done
        if read_done = '1' then
          primitive_delay <= '0';
        end if;
      end if;
    end if;
  end process;

  -- process bram address
  -- IN: bram_rst - asserted reset signal from register
  -- implements the address latching for the bram
  p_bram_addr : process (CLK, NRST, bram_en, clock_en, read_done)
  begin
    if NRST = '0' then
      addr_set  <= '0';
      read_addr <= (others => '0');
    else
      if rising_edge (CLK) then
        -- fixme(ja): setting addr_set 
        if bram_en = '1' then
          read_addr <= S_CTRL_ADDRESS;
          addr_set  <= '1';
        end if;

        if read_done = '1' then
          addr_set  <= '0';
          read_addr <= (others => '0');
        end if;

      end if; -- CLK
    end if; -- NRST
  end process;

  p_read_bram : process (CLK, NRST, S_BRAM_RDDATA, addr_set, read_done, primitive_out)
  begin
    if NRST = '0' then
      bram_data     <= (others => '0');
      rd_data_avail <= '0';
    else
      if rising_edge (CLK) then
        -- sample the read data when address has been set and primitive delay has been exhausted
        if addr_set = '1' and primitive_out = '1' then
          bram_data     <= S_BRAM_RDDATA; --latch the data
          rd_data_avail <= '1';
        end if;

        if read_done = '1' then
          rd_data_avail <= '0';
        end if;

      end if; -- CLK
    end if; -- NRST
  end process;

end rtl;
