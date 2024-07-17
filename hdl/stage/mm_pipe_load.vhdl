library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;


entity mm_pipe_load is
    generic (
        C_MM_AXI_ADDR_WIDTH     : integer := 32;
        C_MM_MOD_DATA_WIDTH     : integer := 64;
        C_MM_PIPE_FIFO_DEPTH    : integer := 32
    );
    port (
        CLK : in std_logic;
        NRST : in std_logic;
        EN : in std_logic;
        OP_A : in mm_mult_op;
        OP_B : in mm_mult_op;
        OP_N : in mm_mult_op;
        OP_OUT : out mm_mult_result;
        S_BRAM_ADDRESS : out std_logic_vector (C_MM_AXI_ADDR_WIDTH-1 downto 0);
        S_BRAM_RD_DATA : in std_logic_vector (C_MM_MOD_DATA_WIDTH-1 downto 0);
        S_BRAM_EN      : out std_logic
    );
end mm_pipe_load;

architecture rtl of mm_pipe_load is

    -- todo:
    -- handle the loading of the values from the bram
    -- coupling with the fifo to buffer the data for the operation ? 

    signal bram_address : std_logic_vector (C_MM_AXI_ADDR_WIDTH-1 downto 0);


begin

    process(CLK, NRST)
    begin

    end process;

end architecture;
