library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sim_bram_read is
end sim_bram_read;

architecture sim_rtl of sim_bram_read is
  component mm_bram_ctrl
    generic
    (
      C_S_BRAM_ADDR_WIDTH : integer := 32;
      C_S_BRAM_DATA_WIDTH : integer := 64;
      C_S_BRAM_WE_WIDTH   : integer := 4
    );
    port
    (
      CLK             : in std_logic;
      NRST            : in std_logic;
      S_BRAM_ADDR     : out std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
      S_BRAM_CLK      : out std_logic;
      S_BRAM_WRDATA   : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
      S_BRAM_RDDATA   : in std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
      S_BRAM_EN       : out std_logic;
      S_BRAM_RST      : out std_logic;
      S_BRAM_WE       : out std_logic_vector(C_S_BRAM_WE_WIDTH - 1 downto 0);
      S_CTRL_ADDRESS  : in std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0);
      S_CTRL_REQ_READ : in std_logic;
      S_CTRL_RD_DATA  : out std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0);
      S_CTRL_DONE     : out std_logic;
      S_CTRL_DEBUG    : out std_logic_vector(7 downto 0)
    );
  end component;

  constant half_period         : time      := 1 ns;
  signal finished              : std_logic := '0';
  constant C_S_BRAM_ADDR_WIDTH : integer   := 32;
  constant C_S_BRAM_DATA_WIDTH : integer   := 64;
  constant C_S_BRAM_WE_WIDTH   : integer   := 8;

  signal CLK  : std_logic := '0';
  signal NRST : std_logic;

  signal S_BRAM_ADDR     : std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0)  := (others => '0');
  signal S_BRAM_CLK      : std_logic                                           := '0';
  signal S_BRAM_WRDATA   : std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0)  := (others => '0');
  signal S_BRAM_RDDATA   : std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0)  := (others => '0');
  signal S_BRAM_EN       : std_logic                                           := '0';
  signal S_BRAM_RST      : std_logic                                           := '0';
  signal S_BRAM_WE       : std_logic_vector(C_S_BRAM_WE_WIDTH - 1 downto 0)    := (others => '0');
  signal S_CTRL_ADDRESS  : std_logic_vector(C_S_BRAM_ADDR_WIDTH - 1 downto 0)  := (others => '0');
  signal S_CTRL_REQ_READ : std_logic                                           := '0';
  signal S_CTRL_RD_DATA  : std_logic_vector(C_S_BRAM_DATA_WIDTH - 1 downto 0)  := (others => '0');
  signal S_CTRL_DONE     : std_logic                                           := '0';
  signal S_CTRL_DEBUG    : std_logic_vector(7 downto 0)                        := (others => '0');
  signal S_CTRL_BUSY     : std_logic                                           := '0';
  signal S_DEBUG_4       : std_logic_vector (C_S_BRAM_DATA_WIDTH - 1 downto 0) := (others => '0');

begin

  CLK <= not CLK after half_period when finished /= '1' else
    '0';

  inst_bram_ctrl : entity work.mm_bram_ctrl
    port map
    (
      CLK  => CLK,
      NRST => NRST,
      -- bram interface
      S_BRAM_ADDR   => S_BRAM_ADDR,
      S_BRAM_CLK    => S_BRAM_CLK,
      S_BRAM_WRDATA => S_BRAM_WRDATA,
      S_BRAM_RDDATA => S_BRAM_RDDATA,
      S_BRAM_EN     => S_BRAM_EN,
      S_BRAM_RST    => S_BRAM_RST,
      S_BRAM_WE     => S_BRAM_WE,
      -- control interface
      S_CTRL_ADDRESS  => S_CTRL_ADDRESS,
      S_CTRL_REQ_READ => S_CTRL_REQ_READ, -- initiate bram read
      S_CTRL_RD_DATA  => S_CTRL_RD_DATA, -- data read from the bram
      S_CTRL_DONE     => S_CTRL_DONE,
      S_CTRL_DEBUG    => S_CTRL_DEBUG,
      S_CTRL_BUSY     => S_CTRL_BUSY,
      S_DEBUG_4       => S_DEBUG_4
    );
  process
  begin
    NRST <= '0';
    wait for 2 ns;
    NRST <= '1';

    S_CTRL_ADDRESS <= std_logic_vector(to_unsigned(42, S_CTRL_ADDRESS'length));
    S_BRAM_RDDATA  <= std_logic_vector(to_unsigned(69, S_BRAM_RDDATA'length));

    wait until rising_edge (CLK);
    S_CTRL_REQ_READ <= '1';
    wait until rising_edge (CLK);
    S_CTRL_REQ_READ <= '0';

    wait until S_CTRL_DONE = '1';

    -- S_CTRL_ADDRESS <= std_logic_vector(to_unsigned(69, S_CTRL_ADDRESS'length));
    -- S_BRAM_RDDATA  <= std_logic_vector(to_unsigned(42, S_BRAM_RDDATA'length));
    -- wait until S_CTRL_DONE = '1';

    wait for 20 ns;
    finished <= '1';

  end process;

end sim_rtl;