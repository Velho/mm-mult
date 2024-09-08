-- this package provides the necessary multiplicatio and accumulate
-- operations for given dsp configuration type.
-- each implementation of dsp has a fixed size for the different operations

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

-- todo(ja): clean this up

package mm_dsp_pkg is

  -- DSP Configuration
  -- use these to select between the possible dsp configurations
  constant USE_DSP48_E1    : boolean := false;  -- Spartan 6-series
  constant USE_DSP48_E2    : boolean := true;   -- Ultrascale+
  constant USE_DSP_GENERIC : boolean := false;  -- Generic implementation

  subtype t_dsp_vec   is std_logic_vector (64-1 downto 0);
  subtype t_dsp_mpi is std_logic_vector (127 downto 0);
  subtype t_dsp_uvec  is unsigned (64-1 downto 0);
  type    t_dsp_array is array (natural range<>) of unsigned (44 downto 0); -- product size 45-bit

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
    mbh : std_logic_vector (9 downto 0);
    mbl : std_logic_vector (17 downto 0);
    lbh : std_logic_vector (17 downto 0);
    lbl : std_logic_vector (17 downto 0); -- from 64-bit, 10-bit is left
  end record;

  -- high-byte  : most significant
  -- mid-byte   :  middle part of the qword
  -- low-byte   : least significant
  type mm_27b_dsp is record
    hb : std_logic_vector (9 downto 0);
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

  function mm_16b_dsp_mult (x, y : t_dsp_vec) return t_dsp_vec;
  -- function performing multiplication with the 32b dsp records
  -- calculates the partial products and returns std logic vector
  function mm_32b_dsp_mult (x, y : t_dsp_vec) return t_dsp_vec;

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
    result.mbh := i (63 downto 54);
    result.mbl := i (53 downto 36);
    result.lbh := i (35 downto 18);
    result.lbl := i (17 downto 0); --
    return result;
  end to_mm_18b_dsp;

  function to_mm_27b_dsp (i : t_dsp_vec) return mm_27b_dsp is
    variable result : mm_27b_dsp;
  begin
    result.hb := i (63 downto 54);  -- 10b
    result.mb := i (53 downto 27);  -- 27b
    result.lb := i (26 downto 0);   -- 27b
    return result;
  end to_mm_27b_dsp;

  function to_mm_32b_dsp (i : t_dsp_vec)  return mm_32b_dsp is
    variable result : mm_32b_dsp;
  begin
    result.mb := i (63 downto 32);
    result.lb := i (31 downto 0);
    return result;
  end to_mm_32b_dsp;

  -- todo(ja): clean this up
  -- todo(ja): CARRY, this requires to multiplication with larger partial buffers
  -- use 128-bits to calculate the products and sum the carry back into the product
  function mm_dsp48e2_mult (x, y : t_dsp_vec) return t_dsp_mpi is
    variable prd        : t_dsp_mpi;
    variable d_x        : mm_27b_dsp;
    variable d_y        : mm_18b_dsp;
    variable h_prt_prd  : t_dsp_array (0 to 3);
    variable m_prt_prd  : t_dsp_array (0 to 3);
    variable l_prt_prd  : t_dsp_array (0 to 3);
    variable part_sums  : t_dsp_array (0 to 5);
    variable c          : unsigned (127 downto 0) := ( others => '0' );
    variable sum        : unsigned (127 downto 0) := ( others => '0' );
    variable padded_hb  : std_logic_vector (26 downto 0); -- padded x 9-bit to 27-bit
    variable padded_mbh : std_logic_vector (17 downto 0); -- padded y 9-bit to 18-bit
  begin
    -- unpack the input 64-bit wide words to match the dsp multiplicator widths
    d_x := to_mm_27b_dsp (x);
    d_y := to_mm_18b_dsp (y);

    -- pad the shorter components to same size as others
    padded_hb := "00000000000000000" & d_x.hb;
    padded_mbh := "00000000" & d_y.mbh;

    -- multiply the unpacked terms together and resize the product to 128
    -- afterwards shift the result depending on which terms are being calculated

    -- resizing the products to 128-bits will make use of the RTL_MULT
    -- elements instead of the dsp elements

    -- partial products
    l_prt_prd(0) := unsigned(d_x.lb) * unsigned(d_y.lbl);
    l_prt_prd(1) := unsigned(d_x.lb) * unsigned(d_y.lbh) sll 18;
    l_prt_prd(2) := unsigned(d_x.lb) * unsigned(d_y.mbl) sll 36;
    l_prt_prd(3) := unsigned(d_x.lb) * unsigned(padded_mbh) sll 54;

    report "l(0): " & to_hstring(l_prt_prd(0)) & "h";
    report "l(1): " & to_hstring(l_prt_prd(1)) & "h";
    report "l(2): " & to_hstring(l_prt_prd(2)) & "h";
    report "l(3): " & to_hstring(l_prt_prd(3)) & "h";

    m_prt_prd(0) := unsigned(d_x.mb) * unsigned(d_y.lbl) sll 27;
    m_prt_prd(1) := unsigned(d_x.mb) * unsigned(d_y.lbh) sll 45;
    m_prt_prd(2) := unsigned(d_x.mb) * unsigned(d_y.mbl) sll 63;
    m_prt_prd(3) := unsigned(d_x.mb) * unsigned(padded_mbh) sll 81;

    report "m(0): " & to_hstring(m_prt_prd(0)) & "h";
    report "m(1): " & to_hstring(m_prt_prd(1)) & "h";
    report "m(2): " & to_hstring(m_prt_prd(2)) & "h";
    report "m(3): " & to_hstring(m_prt_prd(3)) & "h";

    h_prt_prd(0) := unsigned(padded_hb) * unsigned(d_y.lbl) sll 54;
    h_prt_prd(1) := unsigned(padded_hb) * unsigned(d_y.lbh) sll 72;
    h_prt_prd(2) := unsigned(padded_hb) * unsigned(d_y.mbl) sll 90;
    h_prt_prd(3) := unsigned(padded_hb) * unsigned(padded_mbh) sll 108;

    report "h(0): " & to_hstring(h_prt_prd(0)) & "h";
    report "h(1): " & to_hstring(h_prt_prd(1)) & "h";
    report "h(2): " & to_hstring(h_prt_prd(2)) & "h";
    report "h(3): " & to_hstring(h_prt_prd(3)) & "h";

    -- high
    sum := h_prt_prd(0) + h_prt_prd(1);
    sum := sum + h_prt_prd(2) + h_prt_prd(3);

    -- mid
    sum := sum + m_prt_prd(0) + m_prt_prd(1);
    sum := sum + m_prt_prd(2) + m_prt_prd(3);

    -- low
    sum := sum + l_prt_prd(0) + l_prt_prd(1);
    sum := sum + l_prt_prd(2) + l_prt_prd(3);

    -- truncation should be done outside of the function
    -- the client will deal then correctly with the carry produced
    -- truncate product to 64-bits
    prd := std_logic_vector (sum);
    report "prd: " & to_hstring(prd) & "h";

    return std_logic_vector(prd);
  end mm_dsp48e2_mult;


  function mm_16b_dsp_mult (x, y : t_dsp_vec) return t_dsp_vec is
    variable prd : t_dsp_vec;
    variable d_x : mm_16b_dsp;
    variable d_y : mm_16b_dsp;
    variable part_prds : t_dsp_array (0 to 15); -- partial products
  begin
    d_x := to_mm_16b_dsp (x);
    d_y := to_mm_16b_dsp (y);

    return prd;
  end mm_16b_dsp_mult;

  function mm_32b_dsp_mult (x, y : t_dsp_vec) return t_dsp_vec is
    variable prt_prod  : mm_partial_product;      -- partial products for x and y
    variable prt_suml : unsigned (63 downto 0);  -- sum of partial product low bytes
    variable prt_sumh : unsigned (63 downto 0);  -- sum of partial product high bytes
    variable product : t_dsp_vec;
    variable d_x : mm_32b_dsp;
    variable d_y : mm_32b_dsp;
  begin
    d_x := to_mm_32b_dsp (x);
    d_y := to_mm_32b_dsp (y);

    prt_prod.mult_ll := resize (unsigned(d_x.lb) * unsigned(d_y.lb), 64);
    prt_prod.mult_lh := resize (unsigned(d_x.lb) * unsigned(d_y.mb), 64) sll 32;
    prt_prod.mult_hl := resize (unsigned(d_x.mb) * unsigned(d_y.lb), 64) sll 32;
    prt_prod.mult_hh := resize (unsigned(d_x.mb) * unsigned(d_y.mb), 64) sll 64;

    prt_suml := prt_prod.mult_ll + prt_prod.mult_lh + prt_prod.mult_hl;
    prt_sumh := prt_suml + prt_prod.mult_hh;

    return std_logic_vector (prt_sumh);
  end mm_32b_dsp_mult;

  -- todo: how does this fit into dsp blocks without the final addition ?
  -- does it cascade properly ? what about carry and borrow ?

  function dsp_mult(x, y: t_dsp_vec) return t_dsp_mpi is
  begin
    if USE_DSP48_E2 then
      return mm_dsp48e2_mult(x, y);
    elsif USE_DSP_GENERIC then
      return mm_32b_dsp_mult(x, y); -- tpod
    -- else case should 16b multiplication
    end if;
  end dsp_mult;

  -- fixme:
  function dsp_mult_acc(x, y, a: t_dsp_vec) return t_dsp_mpi is
    variable product  : t_dsp_mpi;
    variable result   : t_dsp_mpi;
  begin
    -- result = x * y + a
    product := dsp_mult (x, y);
    -- result  := std_logic_vector(resize (unsigned(product) + unsigned(a), 64));
    -- todo still needs to be resized
    result  := std_logic_vector(unsigned(a) + unsigned(product));

    return std_logic_vector(result);
  end dsp_mult_acc;

end package body mm_dsp_pkg;

