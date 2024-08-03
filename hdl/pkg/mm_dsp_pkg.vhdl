-- this package provides the necessary multiplicatio and accumulate
-- operations for given dsp configuration type.
-- each implementation of dsp has a fixed size for the different operations

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;


package mm_dsp_pkg is

  -- DSP Configuration
  -- use these to select between the possible dsp configurations
  constant USE_DSP48_E1    : boolean := false;  -- Spartan 6-series
  constant USE_DSP48_E2    : boolean := true;   -- Ultrascale+
  constant USE_DSP_GENERIC : boolean := false;  -- Generic implementation

  subtype t_dsp_vec   is std_logic_vector (64-1 downto 0);
  subtype t_dsp_uvec  is unsigned (64-1 downto 0);
  type    t_dsp_array is array (natural range<>) of unsigned (63 downto 0); -- product size 45-bit

  -- lbl: least significant byte low
  -- lbl: least significant byte high
  -- mbl: most significant byte low
  -- mbl: most significant byte high
  type mm_16b_dsp is record
    mbh : std_logic_vector (C_DSP_WIDTH-1 downto 0);
    mbl : std_logic_vector (C_DSP_WIDTH-1 downto 0);
    lbh : std_logic_vector (C_DSP_WIDTH-1 downto 0);
    lbl : std_logic_vector (C_DSP_WIDTH-1 downto 0);
  end record;

  -- 18-bit dsp record used for the dsp48e2 multiplicant
  type mm_18b_dsp is record
    mbh : std_logic_vector (17 downto 0);
    mbl : std_logic_vector (17 downto 0);
    lbh : std_logic_vector (17 downto 0);
    lbl : std_logic_vector (17 downto 0); -- from 64-bit, 10-bit is left
  end record;

  -- high-byte  : most significant
  -- mid-byte   :  middle part of the qword
  -- low-byte   : least significant
  type mm_27b_dsp is record
    hb : std_logic_vector (26 downto 0);
    mb : std_logic_vector (26 downto 0);
    lb : std_logic_vector (26 downto 0); -- from 64-bit, 10-bit is left
  end record;

  type mm_32b_dsp is record
    mb : std_logic_vector (31 downto 0);
    lb : std_logic_vector (31 downto 0);
  end record;

  type mm_partial_product is record
    mult_hh : unsigned (63 downto 0);
    mult_hl : unsigned (63 downto 0);
    mult_lh : unsigned (63 downto 0);
    mult_ll : unsigned (63 downto 0);
  end record;

  -- Helper Functions --

  -- function to unpack the 64-bit std logic vector into 16-bit components
  -- \ret mm_16b_dsp record
  function to_mm_16b_dsp (i : t_dsp_vec) return mm_16b_dsp;

  -- function to unpack the 64-bit std logic vector into 18-bit components
  -- unpacking 18b gives us 3 full-sized 18-bit vectors and 10-bit leftover.
  -- \ret mm_18b_dsp
  function to_mm_18b_dsp (i : t_dsp_vec) return mm_18b_dsp;

  -- function to unpack the 64-bit std logic vector into three components
  -- 2x 27-bit inputs and 1x 10-bit
  -- \ret mm_27b_dsp
  function to_mm_27b_dsp (i : t_dsp_vec) return mm_27b_dsp;

  -- function to unpack the 64-bit std logic vector into two 32-bit components
  -- \ret mm_32b_dsp
  function to_mm_32b_dsp (i : t_dsp_vec) return mm_32b_dsp;

  -- DSP Functions --

  -- dsp multiplication optimized for the dsp48e2
  -- input is 64-bit wide std logic vector and multiplies the
  -- inputs and produces std logic vector as an output.
  function mm_dsp48e2_mult (x, y : t_dsp_vec) return t_dsp_vec;
  -- function performing multiplication with the 32b dsp records
  -- calculates the partial products and returns std logic vector
  function mm_32b_dsp_mult (x, y : mm_32b_dsp) return t_dsp_vec;
  function dsp_mult(x, y: t_dsp_vec) return t_dsp_vec;
  function dsp_mult_acc(x, y, a: t_dsp_vec) return t_dsp_vec;

end package mm_dsp_pkg;

package body mm_dsp_pkg is
  function to_mm_16b_dsp (i : t_dsp_vec) return mm_16b_dsp is
    variable result : mm_16b_dsp;
  begin
    result.mbh := i (63 downto 48);
    result.mbl := i (47 downto 32);
    result.lbh := i (31 downto 16);
    result.lbl := i (15 downto 0);
    return result;
  end to_mm_16b_dsp;

  function to_mm_18b_dsp (i : t_dsp_vec) return mm_18b_dsp is
    variable result : mm_18b_dsp;
  begin
    result.mbh := i (63 downto 46);
    result.mbl := i (45 downto 28);
    result.lbh := i (27 downto 10);
    result.lbl := "00000000" & i (9 downto 0); -- pad to 18-bit
    return result;
  end to_mm_18b_dsp;

  function to_mm_27b_dsp (i : t_dsp_vec) return mm_27b_dsp is
    variable result : mm_27b_dsp;
  begin
    result.hb := i (63 downto 37);  -- 27-bit
    result.mb := i (36 downto 10);   -- 27-bit
    result.lb := "00000000000000000" & i (9 downto 0); -- pad to 27-bit
    return result;
  end to_mm_27b_dsp;

  function to_mm_32b_dsp (i : t_dsp_vec)  return mm_32b_dsp is
    variable result : mm_32b_dsp;
  begin
    result.mb := i (63 downto 32);
    result.lb := i (31 downto 0);
    return result;
  end to_mm_32b_dsp;

  function mm_dsp48e2_mult (x, y : t_dsp_vec) return t_dsp_vec is
    variable prd        : t_dsp_vec; -- resulting product
    variable d_x        : mm_27b_dsp;
    variable d_y        : mm_18b_dsp;
    variable part_prods : t_dsp_array (0 to 11);
    variable part_sums  : t_dsp_array (0 to 5);
    variable p0 : std_logic_vector (44 downto 0);
    variable up_lbl : unsigned (27 downto 0);
    variable up_eb  : unsigned (17 downto 0);
  begin
    d_x := to_mm_27b_dsp (x);
    d_y := to_mm_18b_dsp (y);

    up_lbl := resize(unsigned(d_y.lbl), up_lbl'length);
    up_eb  := resize(unsigned(d_x.eb), up_eb'length);

    report "mm_dsp48e2_mult: x = " & to_hstring(x) & "h";
    report "mm_dsp48e2_mult: y = " & to_hstring(y) & "h";

    report "mm_dsp48e2_mult: d_x.mb = " & to_hstring(d_x.mb) & "h";
    report "mm_dsp48e2_mult: d_x.lb = " & to_hstring(d_x.lb) & "h";
    report "mm_dsp48e2_mult: d_x.eb = " & to_hstring(d_x.eb) & "h";

    -- partial product for all d_x components
    part_prods(0) := resize(unsigned(d_x.lb) * unsigned(d_y.lbl), 64); -- lbl !
    part_prods(1) := resize(unsigned(d_x.lb) * unsigned(d_y.lbh), 64);
    part_prods(2) := resize(unsigned(d_x.lb) * unsigned(d_y.mbl), 64);
    part_prods(3) := resize(unsigned(d_x.lb) * unsigned(d_y.mbh), 64);

    part_prods(5) := resize(unsigned(d_x.mb) * unsigned(d_y.lbh), 64);
    part_prods(6) := resize(unsigned(d_x.mb) * unsigned(d_y.mbl), 64);
    part_prods(7) := resize(unsigned(d_x.mb) * unsigned(d_y.mbh), 64);

    part_prods(4) := resize(unsigned(d_x.mb) * unsigned(d_y.lbl), 64);


    -- fixme: d_x.eb is different size, resize it to correct size
    part_prods(8)  := resize(unsigned(d_x.eb) * unsigned(d_y.lbl), 64);
    part_prods(9)  := resize(unsigned(d_x.eb) * unsigned(d_y.lbh), 64);
    part_prods(10) := resize(unsigned(d_x.eb) * unsigned(d_y.mbl), 64);
    part_prods(11) := resize(unsigned(d_x.eb) * unsigned(d_y.mbh), 64);

    report "mm_dsp48e2_mult: part_prods(8) = " & to_hstring(part_prods(8)) & "h";
    report "mm_dsp48e2_mult: part_prods(9) = " & to_hstring(part_prods(9)) & "h";
    report "mm_dsp48e2_mult: part_prods(10) = " & to_hstring(part_prods(10)) & "h";
    report "mm_dsp48e2_mult: part_prods(11) = " & to_hstring(part_prods(11)) & "h";

    -- produce intermediate sums
    part_sums(0) := (unsigned(part_prods(0)) + unsigned(part_prods(1)));
    part_sums(1) := (unsigned(part_prods(2)) + unsigned(part_prods(3)));
    part_sums(2) := (unsigned(part_prods(4)) + unsigned(part_prods(5)));
    part_sums(3) := (unsigned(part_prods(6)) + unsigned(part_prods(7)));
    part_sums(4) := (unsigned(part_prods(8)) + unsigned(part_prods(9)));
    part_sums(5) := (unsigned(part_prods(10)) + unsigned(part_prods(11)));

    report "mm_dsp48e2_mult: part_sums(0) = " & to_hstring(part_sums(0)) & "h";
    report "mm_dsp48e2_mult: part_sums(1) = " & to_hstring(part_sums(1)) & "h";
    report "mm_dsp48e2_mult: part_sums(2) = " & to_hstring(part_sums(2)) & "h";
    report "mm_dsp48e2_mult: part_sums(3) = " & to_hstring(part_sums(3)) & "h";
    report "mm_dsp48e2_mult: part_sums(4) = " & to_hstring(part_sums(4)) & "h";
    report "mm_dsp48e2_mult: part_sums(5) = " & to_hstring(part_sums(5)) & "h";

    -- produce the result
    -- todo: shift the results around for the correct result?
    prd := std_logic_vector(
      unsigned(part_sums(0)) + unsigned(part_sums(1))
       + unsigned(part_sums(2)) + unsigned(part_sums(3)) + unsigned(part_sums(4)) + unsigned(part_sums(5)));

    report "mm_dsp48e2_mult: prd = " & to_hstring(prd) & "h";
    return prd;
  end mm_dsp48e2_mult;

  function mm_32b_dsp_mult (x, y : mm_32b_dsp) return t_dsp_vec is
    variable prt_prod  : mm_partial_product;      -- partial products for x and y
    variable prt_suml : unsigned (63 downto 0);  -- sum of partial product low bytes
    variable prt_sumh : unsigned (63 downto 0);  -- sum of partial product high bytes
    variable product : t_dsp_vec;
  begin
    prt_prod.mult_ll := resize (unsigned(x.lb) * unsigned(y.lb), 64);
    prt_prod.mult_lh := resize (unsigned(x.lb) * unsigned(y.mb), 64) sll 32;
    prt_prod.mult_hl := resize (unsigned(x.mb) * unsigned(y.lb), 64) sll 32;
    prt_prod.mult_hh := resize (unsigned(x.mb) * unsigned(y.mb), 64) sll 64;

    prt_suml := prt_prod.mult_ll + prt_prod.mult_lh + prt_prod.mult_hl;
    prt_sumh := prt_suml + prt_prod.mult_hh;

    return std_logic_vector (prt_sumh);
  end mm_32b_dsp_mult;

  -- todo: how does this fit into dsp blocks without the final addition ?
  -- does it cascade properly ? what about carry and borrow ?

  function dsp_mult(x, y: t_dsp_vec) return t_dsp_vec is
    variable d_x : mm_32b_dsp;
    variable d_y : mm_32b_dsp;
  begin
    d_x := to_mm_32b_dsp (x);
    d_y := to_mm_32b_dsp (y);
    return mm_32b_dsp_mult(d_x, d_y);
  end dsp_mult;

  -- fixme:
  function dsp_mult_acc(x, y, a: t_dsp_vec) return t_dsp_vec is
    variable product  : t_dsp_vec;
    variable result   : t_dsp_vec;
  begin
    -- result = x * y + a
    product := dsp_mult (x, y);
    result  := std_logic_vector(resize (unsigned(product) + unsigned(a), 64));
    return std_logic_vector(result);
  end dsp_mult_acc;

end package body mm_dsp_pkg;

