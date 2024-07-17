-- Wrapper for the DSP48E2

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity mm_dsp48e2 is
  port
  (
    CLK  : in std_logic;
    NRST : in std_logic;
    A_IN : in std_logic_vector (29 downto 0);
    B_IN : in  std_logic_vector (17 downto 0);
    EN : in std_logic
  );
end mm_dsp48e2;

architecture rtl of mm_dsp48e2 is

  signal XOROUT : std_logic_vector (7 downto 0); -- 8-bit output: XOR data

  -- Cascade inputs and outputs: Cascade Ports
    signal ACIN : std_logic_vector (29 downto 0); -- 30-bit input: A cascade data
    signal ACOUT : std_logic_vector (29 downto 0); -- 30-bit output: A port cascade
    signal BCIN : std_logic_vector (17 downto 0); -- 18-bit input: B cascade
    signal BCOUT : std_logic_vector (17 downto 0); -- 18-bit output: B cascade
    signal CARRYCASCIN : std_logic; -- 1-bit input: Cascade carry
    signal CARRYCASCOUT : std_logic; -- 1-bit output: Cascade carry
    signal MULTSIGNIN : std_logic; -- 1-bit input: Multiplier sign cascade
    signal MULTSIGNOUT : std_logic; -- 1-bit output: Multiplier sign cascade
    signal PCIN : std_logic_vector (47 downto 0); -- 48-bit input: P cascade
    signal PCOUT : std_logic_vector (47 downto 0); -- 48-bit output: Cascade output

    -- Control inputs: Control Inputs/Status Bits
    signal ALUMODE : std_logic_vector (3 downto 0); -- 4-bit input: ALU control
    signal CARRYINSEL : std_logic_vector(2 downto 0); -- 3-bit input: Carry select

    signal INMODE : std_logic_vector (4 downto 0); -- 5-bit input: INMODE control
    signal OPMODE : std_logic_vector (8 downto 0); -- 9-bit input: Operation mode

    -- Control outputs: Control Inputs/Status Bits
    signal OVERFLOW : std_Logic; -- 1-bit output: Overflow in add/acc
    signal PATTERNBDETECT : std_logic; -- 1-bit output: Pattern bar detect
    signal PATTERNDETECT : std_logic; -- 1-bit output: Pattern detect
    signal UNDERFLOW : std_logic; -- 1-bit output: Underflow in add/acc

    -- Data inputs: Data Ports
    signal A : std_logic_vector (29 downto 0); -- 30-bit input: A data
    signal B : std_logic_vector (17 downto 0); -- 18-bit input: B data
    signal C : std_logic_vector (47 downto 0); -- 48-bit input: C data
    signal CARRYIN : std_logic; -- 1-bit input: Carry-in
    signal CARRYOUT : std_logic_vector (3 downto 0); -- 4-bit output: Carry
    signal D : std_logic_vector (26 downto 0); -- 27-bit input: D data
    signal P : std_logic_vector (47 downto 0); -- 48-bit output: Primary data

    -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
    signal CEA1 : std_logic; -- 1-bit input: Clock enable for 1st stage AREG
    signal CEA2 : std_logic; -- 1-bit input: Clock enable for 2nd stage AREG
    signal CEAD : std_logic; -- 1-bit input: Clock enable for ADREG
    signal CEALUMODE : std_logic; -- 1-bit input: Clock enable for ALUMODE
    signal CEB1 : std_logic; -- 1-bit input: Clock enable for 1st stage BREG
    signal CEB2 : std_logic; -- 1-bit input: Clock enable for 2nd stage BREG
    signal CEC : std_logic; -- 1-bit input: Clock enable for CREG
    signal CECARRYIN : std_logic; -- 1-bit input: Clock enable for CARRYINREG
    signal CECTRL : std_logic; -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
    signal CED : std_logic; -- 1-bit input: Clock enable for DREG
    signal CEINMODE : std_logic; -- 1-bit input: Clock enable for INMODEREG
    signal CEM : std_logic; -- 1-bit input: Clock enable for MREG
    signal CEP : std_logic; -- 1-bit input: Clock enable for PREG
    signal RSTA : std_logic; -- 1-bit input: Reset for AREG
    signal RSTALLCARRYIN : std_logic; -- 1-bit input: Reset for CARRYINREG
    signal RSTALUMODE : std_logic; -- 1-bit input: Reset for ALUMODEREG
    signal RSTB : std_logic; -- 1-bit input: Reset for BREG
    signal RSTC : std_logic; -- 1-bit input: Reset for CREG
    signal RSTCTRL : std_logic; -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
    signal RSTD : std_logic; -- 1-bit input: Reset for DREG and ADREG
    signal RSTINMODE : std_logic; -- 1-bit input: Reset for INMODEREG
    signal RSTM : std_logic; -- 1-bit input: Reset for MREG
    signal RSTP : std_logic; -- 1-bit input: Reset for PREG
  
begin

  -- drive ports
  ACIN <= A_IN;
  BCIN <= B_IN;

  -- inverted reset ? 
  RSTALUMODE <= not NRST;
  -- drive clock en
  CEALUMODE <= EN;

  -- DSP48E2: 48-bit Multi-Functional Arithmetic Block
  --          Kintex UltraScale+
  -- Xilinx HDL Language Template, version 2023.2

  DSP48E2_inst : DSP48E2
  generic map (
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL    => "A", -- Selects A input to multiplier (A, AD)
    A_INPUT     => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL    => "B", -- Selects B input to multiplier (AD, B)
    B_INPUT     => "DIRECT", -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
    PREADDINSEL => "A", -- Selects input to pre-adder (A, B)
    RND         => X"000000000000", -- Rounding Constant
    USE_MULT    => "MULTIPLY", -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
    USE_SIMD    => "ONE48", -- SIMD selection (FOUR12, ONE48, TWO24)
    USE_WIDEXOR => "FALSE", -- Use the Wide XOR function (FALSE, TRUE)
    XORSIMD     => "XOR24_48_96", -- Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
    -- Pattern Detector Attributes: Pattern Detection Configuration
    AUTORESET_PATDET   => "NO_RESET", -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
    AUTORESET_PRIORITY => "RESET", -- Priority of AUTORESET vs. CEP (CEP, RESET).
    MASK               => X"3fffffffffff", -- 48-bit mask value for pattern detect (1=ignore)
    PATTERN            => X"000000000000", -- 48-bit pattern match for pattern detect
    SEL_MASK           => "MASK", -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
    SEL_PATTERN        => "PATTERN", -- Select pattern value (C, PATTERN)
    USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
    -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
    IS_ALUMODE_INVERTED       => "0000", -- Optional inversion for ALUMODE
    IS_CARRYIN_INVERTED       => '0', -- Optional inversion for CARRYIN
    IS_CLK_INVERTED           => '0', -- Optional inversion for CLK
    IS_INMODE_INVERTED        => "00000", -- Optional inversion for INMODE
    IS_OPMODE_INVERTED        => "000000000", -- Optional inversion for OPMODE
    IS_RSTALLCARRYIN_INVERTED => '0', -- Optional inversion for RSTALLCARRYIN
    IS_RSTALUMODE_INVERTED    => '0', -- Optional inversion for RSTALUMODE
    IS_RSTA_INVERTED          => '0', -- Optional inversion for RSTA
    IS_RSTB_INVERTED          => '0', -- Optional inversion for RSTB
    IS_RSTCTRL_INVERTED       => '0', -- Optional inversion for RSTCTRL
    IS_RSTC_INVERTED          => '0', -- Optional inversion for RSTC
    IS_RSTD_INVERTED          => '0', -- Optional inversion for RSTD
    IS_RSTINMODE_INVERTED     => '0', -- Optional inversion for RSTINMODE
    IS_RSTM_INVERTED          => '0', -- Optional inversion for RSTM
    IS_RSTP_INVERTED          => '0', -- Optional inversion for RSTP
    -- Register Control Attributes: Pipeline Register Configuration
    ACASCREG      => 1, -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
    ADREG         => 1, -- Pipeline stages for pre-adder (0-1)
    ALUMODEREG    => 1, -- Pipeline stages for ALUMODE (0-1)
    AREG          => 1, -- Pipeline stages for A (0-2)
    BCASCREG      => 1, -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
    BREG          => 1, -- Pipeline stages for B (0-2)
    CARRYINREG    => 1, -- Pipeline stages for CARRYIN (0-1)
    CARRYINSELREG => 1, -- Pipeline stages for CARRYINSEL (0-1)
    CREG          => 1, -- Pipeline stages for C (0-1)
    DREG          => 1, -- Pipeline stages for D (0-1)
    INMODEREG     => 1, -- Pipeline stages for INMODE (0-1)
    MREG          => 1, -- Multiplier pipeline stages (0-1)
    OPMODEREG     => 1, -- Pipeline stages for OPMODE (0-1)
    PREG          => 1 -- Number of pipeline stages for P (0-1)
  )
  port map
  (
    -- Cascade outputs: Cascade Ports
    ACOUT        => ACOUT, -- 30-bit output: A port cascade
    BCOUT        => BCOUT, -- 18-bit output: B cascade
    CARRYCASCOUT => CARRYCASCOUT, -- 1-bit output: Cascade carry
    MULTSIGNOUT  => MULTSIGNOUT, -- 1-bit output: Multiplier sign cascade
    PCOUT        => PCOUT, -- 48-bit output: Cascade output
    -- Control outputs: Control Inputs/Status Bits
    OVERFLOW       => OVERFLOW, -- 1-bit output: Overflow in add/acc
    PATTERNBDETECT => PATTERNBDETECT, -- 1-bit output: Pattern bar detect
    PATTERNDETECT  => PATTERNDETECT, -- 1-bit output: Pattern detect
    UNDERFLOW      => UNDERFLOW, -- 1-bit output: Underflow in add/acc
    -- Data outputs: Data Ports
    CARRYOUT => CARRYOUT, -- 4-bit output: Carry
    P        => P, -- 48-bit output: Primary data
    XOROUT   => XOROUT, -- 8-bit output: XOR data
    -- Cascade inputs: Cascade Ports
    ACIN        => ACIN, -- 30-bit input: A cascade data
    BCIN        => BCIN, -- 18-bit input: B cascade
    CARRYCASCIN => CARRYCASCIN, -- 1-bit input: Cascade carry
    MULTSIGNIN  => MULTSIGNIN, -- 1-bit input: Multiplier sign cascade
    PCIN        => PCIN, -- 48-bit input: P cascade
    -- Control inputs: Control Inputs/Status Bits
    ALUMODE    => ALUMODE, -- 4-bit input: ALU control
    CARRYINSEL => CARRYINSEL, -- 3-bit input: Carry select
    CLK        => CLK, -- 1-bit input: Clock
    INMODE     => INMODE, -- 5-bit input: INMODE control
    OPMODE     => OPMODE, -- 9-bit input: Operation mode
    -- Data inputs: Data Ports
    A       => A, -- 30-bit input: A data
    B       => B, -- 18-bit input: B data
    C       => C, -- 48-bit input: C data
    CARRYIN => CARRYIN, -- 1-bit input: Carry-in
    D       => D, -- 27-bit input: D data
    -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
    CEA1          => CEA1, -- 1-bit input: Clock enable for 1st stage AREG
    CEA2          => CEA2, -- 1-bit input: Clock enable for 2nd stage AREG
    CEAD          => CEAD, -- 1-bit input: Clock enable for ADREG
    CEALUMODE     => CEALUMODE, -- 1-bit input: Clock enable for ALUMODE
    CEB1          => CEB1, -- 1-bit input: Clock enable for 1st stage BREG
    CEB2          => CEB2, -- 1-bit input: Clock enable for 2nd stage BREG
    CEC           => CEC, -- 1-bit input: Clock enable for CREG
    CECARRYIN     => CECARRYIN, -- 1-bit input: Clock enable for CARRYINREG
    CECTRL        => CECTRL, -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
    CED           => CED, -- 1-bit input: Clock enable for DREG
    CEINMODE      => CEINMODE, -- 1-bit input: Clock enable for INMODEREG
    CEM           => CEM, -- 1-bit input: Clock enable for MREG
    CEP           => CEP, -- 1-bit input: Clock enable for PREG
    RSTA          => RSTA, -- 1-bit input: Reset for AREG
    RSTALLCARRYIN => RSTALLCARRYIN, -- 1-bit input: Reset for CARRYINREG
    RSTALUMODE    => RSTALUMODE, -- 1-bit input: Reset for ALUMODEREG
    RSTB          => RSTB, -- 1-bit input: Reset for BREG
    RSTC          => RSTC, -- 1-bit input: Reset for CREG
    RSTCTRL       => RSTCTRL, -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
    RSTD          => RSTD, -- 1-bit input: Reset for DREG and ADREG
    RSTINMODE     => RSTINMODE, -- 1-bit input: Reset for INMODEREG
    RSTM          => RSTM, -- 1-bit input: Reset for MREG
    RSTP          => RSTP -- 1-bit input: Reset for PREG
  );

end architecture;