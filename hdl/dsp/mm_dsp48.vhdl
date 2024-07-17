-- vim: noai:ts=2:sw=2
-- Infers the Xilinx DSP using the USE_DSP attribute.
-- References: ug901-vivado-synthesis-design-guide.pdf
-- Port signals have been defined in the confines of the supporting
-- dsp primitivies. This is to optimize the dsp operations necessary
-- to be performed. Ultrascale+ architecture provides us with the DSP48E2
-- Multiplier widths used to make sure dsp blocks will be synthetised
-- Velho

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

entity mm_dsp48_mult is
  generic
  (
    WIDTHA : integer := 27;
    WIDTHB : integer := 18
  );
  port
  (
    CLK  : in std_logic;
    NRST : in std_logic;
    A    : in std_logic_vector (WIDTHA - 1 downto 0);
    B    : in std_logic_vector (WIDTHB - 1 downto 0);

    RES : out std_logic_vector (WIDTHA + WIDTHB - 1 downto 0)
  );
end mm_dsp48_mult;

architecture rtl_dsp of mm_dsp48_mult is
  -- use_dsp attribute to infer dsp primitive
  attribute use_dsp : string;
  attribute use_dsp of CLK : signal is "yes";
  attribute use_dsp of NRST : signal is "yes";
  attribute use_dsp of A : signal is "yes";
  attribute use_dsp of B : signal is "yes";
  attribute use_dsp of RES : signal is "yes";

  signal result : std_logic_vector (WIDTHA + WIDTHB - 1 downto 0);

begin

  RES <= result;

  p_mult: process (CLK, NRST)
  begin
    if NRST = '0' then
        result <= ( others => '0' );
    else
      if rising_edge (CLK) then
        result <= A * B;
      end if;
    end if;
  end process;
end rtl_dsp;
