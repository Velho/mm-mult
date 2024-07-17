-- vim: noai:ts=2:sw=2
----------------------------------------------------------------------------------
-- Author: Velho
-- 
-- Create Date: 05/24/2024 11:43:31 PM
-- Module Name: mm_mult_top - rtl
-- Project Name: 
-- Description: 
-- 
-- Dependencies: 
--  - Xilinx BRAM Memory IP Core
--    BRAM Controller implemented produces signals compatible
--    with this IP core.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mm_mult is
  generic
  (
    -- Width of S_AXI data bus
    C_S_AXI_DATA_WIDTH : integer := 64;
    -- Width of S_AXI address bus
    C_S_AXI_ADDR_WIDTH : integer := 8;

    C_S_BRAM_ADDR_WIDTH : integer := 32;
    C_S_BRAM_DATA_WIDTH : integer := 64;
    C_S_BRAM_WE_WIDTH   : integer := 8;
    C_S_FIFO_DATA_WIDTH : integer := 64
  );
  port
  (
    S_AXI_ACLK    : in std_logic;
    S_AXI_ARESETN : in std_logic;

    S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
    S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;
    S_AXI_WDATA   : in std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    S_AXI_WSTRB   : in std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
    S_AXI_WVALID  : in std_logic;
    S_AXI_WREADY  : out std_logic;
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in std_logic;
    S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
    S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;
    S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in std_logic;

    -- BRAM ports
    S_BRAM_ADDR   : out std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
    S_BRAM_CLK    : out std_logic;
    S_BRAM_WRDATA : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
    S_BRAM_RDDATA : in std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
    S_BRAM_EN     : out std_logic;
    S_BRAM_RST    : out std_logic;
    S_BRAM_WE     : out std_logic_vector(C_S_BRAM_WE_WIDTH-1 downto 0);


    S_FIFO_DIN : out std_logic_vector(C_S_FIFO_DATA_WIDTH-1 downto 0); -- FIFO Write Data (required)
    S_FIFO_WR_EN : out std_logic; -- FIFO Write Enable (required)
    S_FIFO_FULL : in std_logic; -- FIFO Full flag (optional)
    -- S_FIFO_WR_ALMOST_FULL : out std_logic; -- FIFO Almost full flag (optional)

    S_FIFO_RD_DATA : in std_logic_vector(C_S_FIFO_DATA_WIDTH-1 downto 0); -- FIFO Read Data (required)
    S_FIFO_RD_EN : out std_logic; -- FIFO Read Enable (required)
    S_FIFO_EMPTY : in std_logic; -- FIFO Empty flag (optional)
    -- S_FIFO_RD_ALMOST_EMPTY : out std_logic; -- FIFO Almost Empty flag (optional)
  
    S_DEBUG_1 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_DEBUG_2 : out std_logic_vector(C_S_BRAM_DATA_WIDTH-1 downto 0);
    S_DEBUG_3 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_DEBUG_4 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_DEBUG_5 : out std_logic
  );
end mm_mult;

architecture rtl of mm_mult is

  -- registers mapped from the axi bus
  signal reg_a      : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- User register 1
  signal reg_ctrl   : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- Control register
  signal reg_status : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- Control register

  signal control_clear : std_logic;
  signal bram_rd       : std_logic;

  signal bram_en : std_logic;
  signal bram_address : std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
  signal bram_data    : std_logic_vector (C_S_BRAM_DATA_WIDTH - 1 downto 0);
  signal bram_read_req : std_logic;
  signal req_rd       : std_logic;
  signal req_done     : std_logic;
  signal bctrl_busy : std_logic;

  signal ctrl_debug : std_logic_vector (7 downto 0);

  signal fifo_element_count : integer;
  signal fifo_din : std_logic_vector(C_S_FIFO_DATA_WIDTH-1 downto 0);


  signal OP_A : mm_mult_op;
  signal OP_B : mm_mult_op;
  signal OP_N : mm_mult_op;
  signal OP_MM : mm_mult_result; -- MM is not a reference to bram

  -- where other operands are references to the bram
  -- result is value of the result
  signal OP_RESULT : mm_mult_result;

  -- control signals for the mm_mod
  signal s_req_op : std_logic;
  signal s_req_store : std_logic;

  constant MAX_COUNTER : unsigned (31 downto 0) := x"ffffffff";
  signal clock_counter : unsigned(31 downto 0);
  signal t_clock_counter : std_logic_vector(31 downto 0);
begin

  S_DEBUG_1(31 downto 0) <= bram_address;
  S_DEBUG_2 <= bram_data;
  -- S_DEBUG_3 <= (63 downto 4 => '0', 3 => bram_en, 2 => control_clear, 1 => req_done, 0 => req_rd);
  S_DEBUG_3(3 downto 0) <= (3 => bram_en, 2 => control_clear, 1 => req_done, 0 => req_rd);
  S_DEBUG_3(35 downto 4) <= std_logic_vector(clock_counter);
  -- S_DEBUG_3(36 downto 4) <= std_logic_vector(clock_counter);

  S_DEBUG_5 <= control_clear;
  -- t_clock_counter <= std_logic_vector(clock_counter);

  -- drive the io ports
  S_BRAM_EN <= bram_en;
  S_FIFO_DIN <= fifo_din;



  inst_axilite : entity work.mm_axi4lite
  port map
  (
    S_AXI_ACLK      => S_AXI_ACLK,
    S_AXI_ARESETN   => S_AXI_ARESETN,
    S_AXI_AWADDR    => S_AXI_AWADDR,
    S_AXI_AWPROT    => S_AXI_AWPROT,
    S_AXI_AWVALID   => S_AXI_AWVALID,
    S_AXI_AWREADY   => S_AXI_AWREADY,
    S_AXI_WDATA     => S_AXI_WDATA,
    S_AXI_WSTRB     => S_AXI_WSTRB,
    S_AXI_WVALID    => S_AXI_WVALID,
    S_AXI_WREADY    => S_AXI_WREADY,
    S_AXI_BRESP     => S_AXI_BRESP,
    S_AXI_BVALID    => S_AXI_BVALID,
    S_AXI_BREADY    => S_AXI_BREADY,
    S_AXI_ARADDR    => S_AXI_ARADDR,
    S_AXI_ARPROT    => S_AXI_ARPROT,
    S_AXI_ARVALID   => S_AXI_ARVALID,
    S_AXI_ARREADY   => S_AXI_ARREADY,
    S_AXI_RDATA     => S_AXI_RDATA,
    S_AXI_RRESP     => S_AXI_RRESP,
    S_AXI_RVALID    => S_AXI_RVALID,
    S_AXI_RREADY    => S_AXI_RREADY,
    S_CONTROL_CLEAR => control_clear,
    S_BRAM_DATA     => bram_data,
    S_OP_A          => OP_A,
    S_OP_B          => OP_B,
    S_OP_N          => OP_N,
    S_OP_MM         => OP_MM
  );


  -- todo: bram_ctrl CTRL_ADDRESS needs to be muxed from whatever
  -- needs to be requested from the memory
  inst_bram_ctrl : entity work.mm_bram_ctrl
  port map (
    CLK  => S_AXI_ACLK,
    NRST => S_AXI_ARESETN,
    -- bram interface
    S_BRAM_ADDR   => S_BRAM_ADDR,
    S_BRAM_CLK    => S_BRAM_CLK,
    S_BRAM_WRDATA => S_BRAM_WRDATA,
    S_BRAM_RDDATA => S_BRAM_RDDATA,
    S_BRAM_EN     => bram_en,
    S_BRAM_RST    => S_BRAM_RST,
    S_BRAM_WE     => S_BRAM_WE,
    -- control interface
    S_CTRL_ADDRESS  => OP_A.BASE_ADDRESS,
    S_CTRL_REQ_READ => bram_read_req, -- initiate bram read
    S_CTRL_RD_DATA  => bram_data, -- data read from the bram
    S_CTRL_DONE     => req_done,
    S_CTRL_DEBUG    => ctrl_debug,
    S_CTRL_BUSY     => bctrl_busy,
    S_DEBUG_4       => S_DEBUG_4
  );

  -- Disable the mm_mod from the axi testbench
  -- mm_mod_inst : entity work.mm_mod
  -- port map (
  --   CLK => S_AXI_ACLK,
  --   NRST => S_AXI_ARESETN,
  --   S_CONTROL_CLEAR => control_clear,
  --   S_BRAM_REQ_OP => s_req_op,
  --   S_BRAM_REQ_STORE => s_req_store,
  --   S_BRAM_REQ_ACK => req_done,
  --   S_BRAM_ADDR => bram_address,
  --   S_BRAM_DATA => bram_data,
  --   OP_A => OP_A,
  --   OP_B => OP_B,
  --   OP_N => OP_N,
  --   OP_MM => OP_MM,
  --   OP_RESULT => OP_RESULT
  -- );

  -- implements fifo store
  -- stores the results for the mm_mod operation into the fifo
  -- before storing them into bram. results are buffered into the
  -- bram so the pipeline does not need to be stalled due to memory
  -- operations.
  p_fifo_store: process (S_AXI_ACLK, S_AXI_ARESETN, S_REQ_STORE)
  begin
    if S_AXI_ARESETN = '0' then
    else
      if rising_edge(S_AXI_ACLK) then
        if S_REQ_STORE = '1' then

          -- check if the fifo is full
          if S_FIFO_FULL = '0' then
          else

          end if;

          -- should we somehow ack when the fifo transfer
          -- has been completed ?
          -- set the dout one clock before asserting enable
        end if;
      end if;
    end if;
  end process;


  process (S_AXI_ACLK, S_AXI_ARESETN, clock_counter)
  begin
    if S_AXI_ARESETN = '0' then
      clock_counter <= ( others => '0' );
    else
      if rising_edge (S_AXI_ACLK) then
        if clock_counter < MAX_COUNTER then
          clock_counter <= clock_counter + 1;
        else
          clock_counter <= ( others => '0' );
        end if;
      end if;
    end if;
  end process;


end rtl;
