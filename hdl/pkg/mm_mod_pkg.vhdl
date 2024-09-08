-- Author: Velho
-- Description:
-- Record package for common types used by the mm_mod
-- These different reords defined here are optimized for the
-- DSP48E2 which is part of the Zynq Ultrascale+

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package mm_mod_pkg is
    constant C_DATA_WIDTH       : integer := 64;
    constant C_BRAM_ADDR_LENGTH : integer := 32;
    constant C_BRAM_ADDR_BITS   : integer := 4;
    constant C_DSP_WIDTH        : integer := 16;
    constant C_DSP_MULTIPLIER   : integer := 27;

    -- Montgomery Multiplication Operand record type
    -- Each operand consists of the address location inside the bram
    -- and how many bytes are stored there as a length. Different
    -- implementations might call the length as limbs
    type mm_mult_op is record
        BASE_ADDRESS : std_logic_vector (C_BRAM_ADDR_LENGTH-1 downto 0);
        LENGTH : std_logic_vector (C_BRAM_ADDR_LENGTH-1 downto 0);
    end record;

    type mm_mult_index is record
      A : integer;
      B : integer;
      N : integer;
    end record;

    -- type definition for the resulting 64-bit value
    subtype mm_mult_result is std_logic_vector (C_DATA_WIDTH-1 downto 0);

    -- fsm type definitions
    type mm_mod_stage is (mm_stage_idle, mm_stage_load, mm_stage_mult, mm_stage_store);
    type mm_op_req is (mm_op_nil, mm_op_a, mm_op_b, mm_op_n);

end package mm_mod_pkg;
