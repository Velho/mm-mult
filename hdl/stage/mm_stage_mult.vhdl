-- vim: noai:ts=2:sw=2
-- velho

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;
use work.mm_dsp_pkg.all;

entity mm_stage_mult is
  generic (
    C_DATA_WIDTH : integer := 64;
    C_RESULT_WIDTH : integer := 64
  );
  port (
    CLK   : in std_logic;
    NRST  : in std_logic;

    S_A   : in std_logic_vector (C_DATA_WIDTH-1 downto 0);
    S_B   : in std_logic_vector (C_DATA_WIDTH-1 downto 0);
    S_N   : in std_logic_vector (C_DATA_WIDTH-1 downto 0);
    S_MM  : in std_logic_vector (C_DATA_WIDTH-1 downto 0);

    -- intermediate result from previous iteration
    S_A0  : in std_logic_vector (C_DATA_WIDTH-1 downto 0);
    S_CARRY_O : out std_logic_vector (C_DATA_WIDTH-1 downto 0);

    -- output from here should be 64-bit wide which will
    -- be stored by the driver for this entity
    S_RESULT : out std_logic_vector (C_RESULT_WIDTH-1 downto 0);

    S_ENABLE  : in std_logic; -- enable
    S_READY   : out std_logic -- computation done
  );
 end mm_stage_mult;

architecture rtl of mm_stage_mult is

  -- define attribute to infer dsp
  attribute use_dsp : string;
  attribute use_dsp of S_A : signal is "yes";
  attribute use_dsp of S_B : signal is "yes";
  attribute use_dsp of S_N : signal is "yes";
  attribute use_dsp of S_MM : signal is "yes";
  attribute use_dsp of S_A0 : signal is "yes";
  attribute use_dsp of S_CARRY_O : signal is "yes";

  signal mm_mult_stage_result : std_logic_vector (C_RESULT_WIDTH-1 downto 0);

  signal ui : std_logic_vector (128-1 downto 0);
  signal ui_rdy : std_logic;

  signal ui1 : std_logic_vector (128-1 downto 0);
  signal ui2 : std_logic_vector (128-1 downto 0);
  signal ui3 : std_logic_vector (128-1 downto 0);
  signal ui4 : std_logic_vector (128-1 downto 0);
  signal ui5 : std_logic_vector (128-1 downto 0);
  signal ui6 : std_logic_vector (128-1 downto 0);
  signal ui7 : std_logic_vector (128-1 downto 0);
  signal ui8 : std_logic_vector (128-1 downto 0);
  signal ui9 : std_logic_vector (128-1 downto 0);
  
  signal t1 : std_logic_vector (128-1 downto 0);
  signal t2 : std_logic_vector (128-1 downto 0);

  signal mm_result : std_logic_vector (C_DATA_WIDTH-1 downto 0);

  signal k1 : std_logic_vector (127 downto 0);
  signal k2 : std_logic_vector (127 downto 0);

  -- dsp itself doesn't have ready signal to assert when
  -- the operation itself has been completed, but this should
  -- take at least 2 clock cycles to perform the necessary calculations
  -- the 64-bit values are unpacked to each individual componets
  -- for better per-clock optimization so we'll assert with 3 clocks of delay
  constant DSP_LATENCY  : integer := 3;
  signal dsp_wait       : integer;
  signal dsp_rdy        : std_logic;

begin

  -- drive outputs
  -- result driven when ENABLE is being asserted
  S_RESULT <= mm_result when S_ENABLE = '1'
            else ( others => '0' );
  S_READY <= dsp_rdy; -- when enabled ?

  -- todo:
  -- implement the mont mul once with using input sizes for the calculations
  -- analyze the dsp usage
  -- optimize
  -- if it's necessary at that time to produce the partial products then lets do so

  -- mm mult starts with calculating the inputs for the multiplication
  -- and accumulate operation.
  -- from the cryptography handbook 14.36 each iteration starts with
  -- ui <- (u0 + xi * y0) * m' mod b
  -- u0 is the result from the previous iteration
  -- mpi format: u1 = (T[0] + u0 * B[0]) * mm

  -- validation results for first T iter for ui should be
  -- 0x6f0940c565c87b5f
  -- with A = 0x1, B = 0x33, N = 0x53

  -- 2.1 ui calculation
  -- ui = (A0 + A * B) * MM
  p_ui_op: process (CLK, NRST)
  begin
    if NRST = '0' then
        ui <= ( others => '0' );
    elsif rising_edge (CLK) then
      if S_ENABLE = '1' then
        -- ui = (A0 + A * B) * MM
        ui1 <= dsp_mult_acc(S_A, S_B, S_A0);
        ui2 <= dsp_mult(ui1, S_MM);
        ui3 <= std_logic_vector(resize(unsigned(ui1) * unsigned(ui2), 128));
        ui4 <= ui3;
        ui5 <= ui4;
        ui6 <= ui5;
        ui7 <= ui6;
        ui8 <= ui7;
        ui9 <= ui8;

        ui <= ui9;
        -- ui <= dsp_mult(dsp_mult_acc(S_A, S_B, S_A0), S_MM);
      end if;
    end if;
  end process;

  -- 2.2 produces the A by calculating
  -- (A + xi * y + ui * m)
  p_mla: process (CLK, NRST)
    variable temp_result1 : std_logic_vector (C_DATA_WIDTH-1 downto 0);
    variable temp_result2 : std_logic_vector (C_DATA_WIDTH-1 downto 0);
  begin
    if NRST = '0' then
      mm_result   <= ( others => '0' );
      t1 <= ( others => '0' );
      k1 <= ( others => '0' );
      t2 <= ( others => '0' );
      k2 <= ( others => '0' );
    elsif rising_edge (CLK) then
      if S_ENABLE = '1' then

        -- todo(ja): doesnt look right, check the variables to the multiplication!
        -- ja: seems to be an issue with the carry operation
        -- when the calculation overflows for the 64-bit, it is then written to the next
        -- limb of the T temporary buffer.

        -- T += A0 * B
        -- t1 <= dsp_mult_acc (S_B, S_A, S_A0);
        -- k1 <= dsp_mult_acc (S_B, S_A, S_A0);

        -- T += ui * N
        -- t2 <= dsp_mult_acc (ui, S_N, t1);
        -- k2 <= dsp_mult_acc (ui, S_N, k1);

        mm_result <= ui(63 downto 0);
      end if;
    end if;
  end process;

  -- implements delay from when the enable has been asserted
  -- to when the actual multiplication product is ready to be sampled
  p_ready_wait: process (CLK, NRST)
  begin
    if NRST = '0' then
      dsp_rdy <= '0';
      dsp_wait <= 0;
    elsif rising_edge (CLK) then
      if S_ENABLE = '1' then
        if dsp_wait >= DSP_LATENCY then
          dsp_rdy <= '1';
        else
          dsp_wait <= dsp_wait + 1;
        end if;
      else
        dsp_wait <= 0;
        dsp_rdy <= '0';
      end if;
    end if;
  end process;

end rtl;

