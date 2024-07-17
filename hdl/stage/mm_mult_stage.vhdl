-- vim: noai:ts=2:sw=2
-- velho

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;


entity mm_mult_stage is
  generic (
    C_DATA_WIDTH : integer := 64
  );
  port (
    CLK : in std_logic;
    NRST : in std_logic

  );
 end mm_mult_stage;

architecture rtl of mm_mult_stage is
begin

end rtl;

