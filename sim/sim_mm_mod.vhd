----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/27/2024 01:32:43 AM
-- Design Name: 
-- Module Name: sim_mm_mod - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity sim_mm_mod is
  --  Port ( );
end sim_mm_mod;
architecture Behavioral of sim_mm_mod is

  constant half_period         : time      := 1 ns;
  signal finished              : std_logic := '0';
  constant C_MM_AXI_ADDR_WIDTH : integer   := 32;
  constant C_MM_MOD_DATA_WIDTH : integer   := 64;
  -- bram size of 16K
  constant C_MM_MOD_ADDR_WIDiTH : integer := 14;

  signal CLK  : std_logic;
  signal NRST : std_logic;

  signal S_CONTROL_CLEAR : std_logic;
  signal S_REQ_OP        : std_logic;

  signal S_REQ_STORE : std_logic;
  signal S_BRAM_ADDR : std_logic_vector (C_MM_AXI_ADDR_WIDTH - 1 downto 0);
  signal S_BRAM_DATA : std_logic_vector (C_MM_MOD_DATA_WIDTH - 1 downto 0);
  signal OP_A        : mm_mult_op;
  signal OP_B        : mm_mult_op;
  signal OP_N        : mm_mult_op;
  signal OP_MM       : mm_mult_result;

  signal OP_RESULT : mm_mult_result;

  signal BRAM_PORTA_0_addr : std_logic_vector (31 downto 0);
  signal BRAM_PORTA_0_clk  : std_logic;
  signal BRAM_PORTA_0_din  : std_logic_vector (63 downto 0);
  signal BRAM_PORTA_0_dout : std_logic_vector (63 downto 0);
  signal BRAM_PORTA_0_en   : std_logic;
  signal BRAM_PORTA_0_we   : std_logic_vector (7 downto 0);

  signal S_CTRL_ADDRESS    : std_logic_vector(31 downto 0);
  signal S_CTRL_REQ_READ   : std_logic;
  signal S_CTRL_RD_DATA    : std_logic_vector(63 downto 0);
  signal S_CTRL_DONE       : std_logic;
  signal S_CTRL_DEBUG      : std_logic_vector(7 downto 0);
  signal S_CTRL_BUSY       : std_logic;
  signal S_DEBUG_4         : std_logic_vector(63 downto 0);

begin

  CLK <= not CLK after half_period when finished /= '1' else
    '0';

  dut : entity work.mm_mod
    port map
    (
      CLK             => CLK,
      NRST            => NRST,
      S_CONTROL_CLEAR => S_CONTROL_CLEAR,
      S_REQ_OP        => S_CTRL_REQ_READ,
      S_REQ_STORE     => S_REQ_STORE,
      S_BRAM_ADDR     => S_BRAM_ADDR,
      S_BRAM_DATA     => S_BRAM_DATA,
      OP_A            => OP_A,
      OP_B            => OP_B,
      OP_N            => OP_N,
      OP_MM           => OP_MM,
      OP_RESULT       => OP_RESULT
    );

  bram : entity work.bram_design_wrapper
    port map (
      BRAM_PORTA_0_addr => S_BRAM_ADDR,
      BRAM_PORTA_0_clk  => CLK,
      BRAM_PORTA_0_din  => BRAM_PORTA_0_din,
      BRAM_PORTA_0_dout => S_BRAM_DATA,
      BRAM_PORTA_0_en   => BRAM_PORTA_0_en,
      BRAM_PORTA_0_we   => BRAM_PORTA_0_we
    );

  bram_controller : entity work.mm_bram_ctrl
    port map(
      CLK             => CLK,
      NRST            => NRST,
      S_BRAM_ADDR     => S_BRAM_ADDR,
      S_BRAM_CLK      => CLK,
      S_BRAM_WRDATA   => BRAM_PORTA_0_din,
      S_BRAM_RDDATA   => S_BRAM_DATA,
      S_BRAM_EN       => BRAM_PORTA_0_en,
      S_BRAM_RST      => NRST, -- not correct reset ?
      S_BRAM_WE       => BRAM_PORTA_0_we,
      S_CTRL_ADDRESS  => S_CTRL_ADDRESS,
      S_CTRL_REQ_READ => S_CTRL_REQ_READ,
      S_CTRL_RD_DATA  => S_CTRL_RD_DATA,
      S_CTRL_DONE     => S_CTRL_DONE,
      S_CTRL_DEBUG    => S_CTRL_DEBUG,
      S_CTRL_BUSY     => S_CTRL_BUSY,
      S_DEBUG_4       => S_DEBUG_4
    );
    
    
  process
  begin
    -- assert reset
    NRST <= '0';
    wait for 2 ns;
    NRST <= '1';

    -- wait for one clock and start the sim
    wait until rising_edge (CLK);
    
    -- OP_A, B and N is set through the AXI interface and needs to be set manually for this simulation
    -- each operand is 64-bits in size, so next address is always shifted by 3 to left
    OP_A.BASE_ADDRESS <= x"0"; -- operand A stored to address x0
    OP_B.BASE_ADDRESS <= x"8"; -- operand B stored to address x8
    OP_N.BASE_ADDRESS <= x"10"; -- operand N stored to address x10
    -- result address should be place after the operand N so x24


    -- perform whatever sim you want here
    S_CONTROL_CLEAR <= '1';
    wait until rising_edge (CLK);
    S_CONTROL_CLEAR <= '0';



    wait for 20 ns;
  end process;

end Behavioral;
