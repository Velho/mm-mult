-- vim: noai:ts=2:sw=2
-- Author: Velho
-- Description:
-- Depending on the axi4lite bus state
-- the output is set.
--
-- 1. User writes the USER0 with a address (4 bytes)
-- 2. User writes 0x0 to the CTRL
-- 3. Value is read from the BRAM at USER0 to STATUS
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

entity mm_axi_addr is
  generic
  (
    -- width of s_axi data bus
    C_S_AXI_DATA_WIDTH : integer := 64;
    -- width of s_axi address bus
    C_S_AXI_ADDR_WIDTH : integer := 8;
    C_S_AXI_ADDR_LSB   : integer := 4
  );

  port
  (
    S_AXI_ACLK    : in std_logic;
    S_AXI_ARESETN : in std_logic;

    S_AXI_AWADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);

    S_AXI_WREN : in std_logic; -- axi write enable
    S_AXI_RDEN : in std_logic; -- axi read enable
    S_AXI_AWEN : in std_logic; -- axi write address
    S_AXI_AREN : in std_logic; -- axi read address

    -- S_REG_STATUS  : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_REG_CTRL : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

    S_CONTROL_CLEAR : out std_logic;

    S_BRAM_A_ADDRESS : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    S_BRAM_A_LENGTH  : in std_logic_vector(C_BRAM_ADDR_LENGTH - 1 downto 0);
    S_BRAM_B_ADDRESS : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    S_BRAM_B_LENGTH  : in std_logic_vector(C_BRAM_ADDR_LENGTH - 1 downto 0);
    S_BRAM_N_ADDRESS : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    S_BRAM_N_LENGTH  : in std_logic_vector(C_BRAM_ADDR_LENGTH - 1 downto 0);
    S_REG_MM : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    S_OP_A : out mm_mult_op;
    S_OP_B : out mm_mult_op;
    S_OP_N : out mm_mult_op;
    S_OP_MM : out mm_mult_result
  );
end mm_axi_addr;
architecture rtl of mm_axi_addr is

  signal axi_addr : integer;

  -- todo(ja): address should be latched to a register so 
  signal bram_address  : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
  signal control_clear : std_logic := '0';

  signal wren_delay : std_logic; -- asserted on the next clock when AXI_WREN has been asserted

  -- signal bram_address  : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

  signal OP_A : mm_mult_op;
  signal OP_B : mm_mult_op;
  signal OP_N : mm_mult_op;
  signal OP_MM : mm_mult_result;

begin
  -- drive output ports
  -- S_BRAM_ADDRESS  <= bram_address; -- when S_AXI_WREN = '1' else (others => '0');
  S_CONTROL_CLEAR <= control_clear; -- when S_AXI_WREN = '1' else '0';
  S_OP_A <= OP_A;
  S_OP_B <= OP_B;
  S_OP_N <= OP_N;
  S_OP_MM <= OP_MM;

  -- 32 bit address is aligned to 4 bytes, 2 lowest bits are skipped
  axi_addr <= to_integer(unsigned(S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH-1 downto C_S_AXI_ADDR_LSB)));

  -- process axi write
  -- IN: S_AXI_WREN - AXI write transaction enabled
  -- IN: wren_delay - local register used to delay sampling
  -- reads the data from axi bus and assigns ports based on the address.
  -- note:
  -- reading of the bus needs to delayed by one clock otherwise
  -- whatever is sampled from the bus is old data.
  p_axi_wr : process (S_AXI_ACLK, S_AXI_ARESETN, S_AXI_WREN, wren_delay)
  begin
    if S_AXI_ARESETN = '0' then
      bram_address  <= (others => '0');
      control_clear <= '0';
      wren_delay    <= '0';
    else
      if rising_edge (S_AXI_ACLK) then
        if S_AXI_WREN = '1' then
          wren_delay <= '1';
        end if;

        if wren_delay = '1' then
          wren_delay <= '0';

          case axi_addr is
            when 0      => OP_A.BASE_ADDRESS <= S_BRAM_A_ADDRESS(work.mm_mod_pkg.C_BRAM_ADDR_LENGTH - 1 downto 0);
            when 1      => OP_A.LENGTH       <= S_BRAM_A_LENGTH;
            when 2      => OP_B.BASE_ADDRESS <= S_BRAM_B_ADDRESS(work.mm_mod_pkg.C_BRAM_ADDR_LENGTH - 1 downto 0);
            when 3      => OP_B.LENGTH       <= S_BRAM_B_LENGTH;
            when 4      => OP_N.BASE_ADDRESS <= S_BRAM_N_ADDRESS(work.mm_mod_pkg.C_BRAM_ADDR_LENGTH - 1 downto 0);
            when 5      => OP_N.LENGTH       <= S_BRAM_N_LENGTH;
            when 6      => S_OP_MM           <= S_REG_MM;
            when 9      => control_clear     <= '1';
            when others => null;
          end case;
        elsif control_clear = '1' then -- control_clear should be de-asserted on the next clock
          control_clear <= '0';
        end if;
      end if;
    end if;
  end process;

end rtl;
