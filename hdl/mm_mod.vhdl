-- vim: noai:ts=2:sw=2
-- Author: Velho
-- Description:
-- implements the montgomery modulos operation
-- Montgomery Multiplication: X = A * B * R^-1 mod N (HAC 14.36)
-- Operation is as follows,
-- 1. User writes the arguments as addresses to the bram with the limb size
-- 2. MM is computed 64-bits at a time
-- 3. While MM is being computed, the BRAM controller should be pulling the next 32 bits
-- 4. Result is stored to the bram
--
-- this results in a pipeline that would look something like
-- BRAM READ > COMPUTE MPI > STORE
--
-- todo(ja):
-- * first step is to test minimal setup with the pipeline
--   where 32 bit values are READ, COMPUTED and STORED into the bram
-- * this concept should be then scaled to larger array types
-- references:
-- https://cacr.uwaterloo.ca/hac/about/chap14.pdf
-- https://en.wikipedia.org/wiki/Montgomery_modular_multiplication
-- https://en.algorithmica.org/hpc/number-theory/montgomery/
-- C implementation https://github.dev/Mbed-TLS/mbedtls/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mm_mod_pkg.all;


entity mm_mod is
  generic (
    C_MM_AXI_ADDR_WIDTH : integer := 32;
    C_MM_MOD_DATA_WIDTH : integer := 64;
    -- bram size of 16K
    C_MM_MOD_ADDR_WIDTH : integer := 14;
    C_MM_MULT_STAGE_COUNT : integer := 4
  );
  port (
    CLK : in std_logic; -- fabric clock
    NRST : in std_logic; -- fabric reset

    S_CONTROL_CLEAR : in std_logic;

    S_BRAM_REQ_OP     : out std_logic;
    S_BRAM_REQ_STORE  : out std_logic;
    S_BRAM_REQ_ACK    : in std_logic;
    S_BRAM_ADDR       : out std_logic_vector (C_MM_AXI_ADDR_WIDTH-1 downto 0);
    S_BRAM_DATA       : in std_logic_vector (C_MM_MOD_DATA_WIDTH-1 downto 0);

    -- Operands required for the mongtomery multiplication
    OP_A  : in mm_mult_op;
    OP_B  : in mm_mult_op;
    OP_N  : in mm_mult_op;
    OP_MM : in mm_mult_result;
    OP_RESULT : out mm_mult_result
  );
end mm_mod;

architecture rtl of mm_mod is

  constant STAGE_COUNT      : integer := 3;
  constant MULT_STAGE_OFFS  : integer := 64;
  constant LAST_OPERAND     : mm_op_req := mm_op_n;
  -- mm_mult_result is value type for data

  type mm_mult_vector is array (0 to C_MM_MULT_STAGE_COUNT-1) of mm_mult_result;

  signal a_value : mm_mult_vector;
  signal b_value : mm_mult_vector;
  signal n_value : mm_mult_vector;

  -- bram control signals
  signal bram_addr : std_logic_vector (C_MM_AXI_ADDR_WIDTH-1 downto 0);
  signal bram_data : std_logic_vector (C_MM_MOD_DATA_WIDTH-1 downto 0);
  signal bram_read_request : std_logic;
  signal bram_write_request : std_logic;

  -- state signals
  -- current_op_req is used only for the load part when we need to pull
  -- multiple operands from the bram sequentially.
  signal current_op_req : mm_op_req :=mm_op_nil;
  signal next_op_req : mm_op_req;
  -- mod pipeline stages
  signal current_mod_stage : mm_mod_stage;
  signal next_mod_stage : mm_mod_stage;

  -- request is set in the start of load stage and requested in the end of the load stage
  signal op_request   : std_logic; -- start reading operands from bram
  signal op_req_completed : std_logic; -- all operands have been requested from bram

  signal op_in  : mm_mult_op;
  signal op_out : mm_mult_result;

  -- have the intermediate values as unsigned ?

begin

  S_BRAM_REQ_OP     <= bram_read_request;
  S_BRAM_REQ_STORE  <= bram_write_request;


  -- 1.
  -- start by performing bram read for the different operations
  -- required. how many operations can be performed 

  -- data read from the bram needs to be performed sequentially
  -- starting from the A to B to N and so on or whatever.

  process (CLK, NRST)
  begin
    -- control the op_load
    -- not to do it in the next_stage as it will just
    -- clutter the state transition logic
    if NRST = '0' then
      op_request <= '0';
    elsif rising_edge (CLK) then
      -- fixme(ja): is this correct condition ?
      -- it takes CONTROL_CLEAR to transition to mm_stage_load
      -- and CONTROL_CLEAR should be asserted for one clock cycle only
      -- so if we are in the load stage already the control clear should
      -- have been de-asserted but what does it then mean if control clear
      -- and stage idle is the condition, do we start pulling the data
      -- on the same clock as we do the transition ? at least we would need
      -- to be in a proper reset state when the bram read is started
      if S_CONTROL_CLEAR = '1' and current_mod_stage = mm_stage_idle then
        op_request <= '1';
      else
        op_request <= '0';
      end if;
    end if;
  end process;

  -- controls the next mod stage with the necessary conditions
  -- IN: current_mod_stage
  p_next_stage_mm: process (CLK, NRST, current_mod_stage)
  begin
    if NRST = '0' then
      next_mod_stage <= mm_stage_idle;
    elsif rising_edge (CLK) then
      -- assign the next stage based on the required
      -- transition condition
      case current_mod_stage is
        when mm_stage_load =>
          -- stage load is completed when all operands
          -- have been requested
          if op_req_completed = '1' then
            next_mod_stage <= mm_stage_mult;
          else
            next_mod_stage <= current_mod_stage;
          end if;
        when mm_stage_mult =>
        when mm_stage_store =>
        when mm_stage_idle =>
          if S_CONTROL_CLEAR = '1' then
            next_mod_stage <= mm_stage_load;
          else
            next_mod_stage <= current_mod_stage;
          end if;
      end case;

    end if;
  end process;

  -- performs the stage state assignment
  -- IN: next_mod_stage
  -- stage condition handlind is done in a different process,
  -- assign the next stage to current.
  p_stage_mm: process (CLK, NRST, next_mod_stage)
  begin
    if NRST = '0' then
      current_mod_stage <= mm_stage_idle;
    elsif rising_edge (CLK) then
      current_mod_stage <= next_mod_stage;
    end if;
  end process; 

  -- next_op_sm: next operand state-machine
  -- valid state: stage_load
  -- IN: current_op_req
  -- state-machine handling the different transitions to pull
  -- the operands from the bram next.
  p_next_op_sm: process (CLK, NRST, current_op_req)
  begin
    if NRST = '0' then
      next_op_req <= mm_op_nil;
    elsif rising_edge (CLK) then
      -- only run the operand requests when load stage is set
      if current_mod_stage = mm_stage_load then
        case current_op_req is
          -- transition sequentially to the next state
          -- when bram request has been acknowledged
          when mm_op_a =>
            if S_BRAM_REQ_ACK = '1' then
              next_op_req <= mm_op_b;
            else
              next_op_req <= current_op_req;
            end if;
          when mm_op_b =>
            if S_BRAM_REQ_ACK = '1' then
              next_op_req <= mm_op_n;
            else
              next_op_req <= current_op_req;
            end if;
          when mm_op_n =>
            if S_BRAM_REQ_ACK = '1' then
              -- load stage completed
              -- set the next op to nil and assert control signal
              -- (done in a separate process)
              next_op_req <= mm_op_nil;
            else
              next_op_req <= current_op_req;
            end if;
          when mm_op_nil =>
            -- start with the operand a
            if op_request = '1' then
              next_op_req <= mm_op_a;
            else
              next_op_req <= current_op_req;
            end if;
        end case;
      end if; -- current_mod_stage
    end if; -- rst and clk
  end process;

  -- assigns the next operand to be requested from bram
  -- IN: next_mod_stage
  p_op_sm: process (CLK, NRST, next_op_req)
  begin
    if NRST = '0' then
      current_op_req <= mm_op_nil;
    elsif rising_edge (CLK) then
      current_op_req <= next_op_req; 
    end if;
  end process;

  -- op requested is asserted when the bram ack
  -- is set while current operand requested is mm_op_n
  -- 
  process (CLK, NRST, current_op_req, S_BRAM_REQ_ACK)
  begin
    if NRST = '0' then
      op_req_completed <= '0';
    elsif rising_edge (CLK) then
      if current_op_req = LAST_OPERAND and S_BRAM_REQ_ACK = '1' then
        op_req_completed <= '1';
      else
        op_req_completed <= '0';
      end if;
    end if;
  end process;

  -- 2.
  -- calculation needed to be performed
  -- u0 = A[i]
  -- u1 = (T[0] + u0 * B[0]) * mm -- where T intermediate result
  -- mla ( d: T, d_len: AN_limbs + 2, s: B, .., b: u0) -- perform T += B * u0
  -- mla ( d: T, .. , s: N, .., b: u1) -- performs T += N * u1

  -- 3.
  -- store the results back into the bram

  -- this results in a 3-stage pipeline for the operation
  -- and the question how much of the second-stage can be
  -- parallelized ?
  -- having vector of 256-bits would enable to be operated
  -- at the time. where each parallel entity would operate
  -- on 64-bit offset of the vector

  -- generate N stages to perform the montgomery multiplication
  -- can be increased or decreased depending on the hw requirements
  mult_stages : for n in (C_MM_MULT_STAGE_COUNT-1) downto 0 generate
    mult_stage: entity work.mm_mult_stage
    port map (
      CLK => CLK,
      NRST => NRST
      -- OP_A => a_value(n),
      -- OP_B => b_value(n),
      -- OP_N => n_value(n),
    );
  end generate mult_stages;

  process (CLK, NRST)
  begin

  end process;

end rtl;
