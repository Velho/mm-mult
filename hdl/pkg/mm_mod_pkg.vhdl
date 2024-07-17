-- vim: noai:ts=2:sw=2
-- Author: Velho
-- Description:
-- Record package for common types used by the mm_mod

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package mm_mod_pkg is
    constant C_DATA_WIDTH : integer := 64;
    constant C_BRAM_ADDR_LENGTH : integer := 32;
    constant C_BRAM_ADDR_BITS : integer := 4;

    -- Montgomery Multiplication Operand record type
    -- Each operand consists of the address location inside the bram
    -- and how many bytes are stored there as a length. Different
    -- implementations might call the length as limbs
    type mm_mult_op is record
        BASE_ADDRESS : std_logic_vector (C_BRAM_ADDR_LENGTH-1 downto 0);
        LENGTH : std_logic_vector (C_BRAM_ADDR_LENGTH-1 downto 0);
    end record;

    subtype mm_mult_result is std_logic_vector (C_DATA_WIDTH-1 downto 0);

    type mm_mod_stage is (mm_stage_idle, mm_stage_load, mm_stage_mult, mm_stage_store);
    type mm_op_req is (mm_op_nil, mm_op_a, mm_op_b, mm_op_n);

end package mm_mod_pkg;
