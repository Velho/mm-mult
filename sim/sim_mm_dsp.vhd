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

entity sim_mm_dsp is
  --  Port ( );
end sim_mm_dsp;

architecture sim_rtl of sim_mm_dsp is

    constant half_period         : time      := 1 ns;
    signal finished              : std_logic := '0';
    constant C_S_BRAM_ADDR_WIDTH : integer   := 32;
    constant C_S_BRAM_DATA_WIDTH : integer   := 64;
    constant C_S_BRAM_WE_WIDTH   : integer   := 8;

    signal CLK  : std_logic := '0';
    signal NRST : std_logic;

    signal A : in std_logic_vector (29 downto 0);
    signal B : in  std_logic_vector (17 downto 0);

begin
    CLK <= not CLK after half_period when finished /= '1' else
    '0';

    dut : entity work.mm_dsp48e2
        port map (
            CLK => CLK,
            NRST => NRST,
            A => A,
            B => B
        );

    process
    begin
        NRST <= '0';
        wait for 2 ns;
        NRST <= '1';

        


    end process;

end sim_rtl;
