--  This file is part of VHDL-FIFO.
--
--  VHDL-FIFO is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Lesser General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  VHDL-FIFO is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.

--  You should have received a copy of the GNU Lesser General Public License
--  along with VHDL-FIFO.  If not, see <http://www.gnu.org/licenses/>.

-- Source: https://github.com/eggsactly/VHDL-FIFO

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.ALL;

entity Fifo is
generic ( 
    DEPTH    :     integer          := 32
    ); 
port    ( 
    CLK      : in  std_logic;
    RST      : in  std_logic;
    W_DATA   : in  std_logic_vector;
    W_EN     : in  std_logic;
    R_DATA   : out std_logic_vector;
    R_EN     : in  std_logic;
    HAS_DATA : out std_logic;
    IS_FULL  : out std_logic
    );
end Fifo;

architecture sim of Fifo is
    constant ADDR_SIZE      : positive := positive(ceil(log2(real(DEPTH))));
    type     registerFileType is array(0 to DEPTH-1) of std_logic_vector(R_DATA'range); 
    signal   registers      : registerFileType := (others=>(others=>'0'));
    signal   READ_ADDR      : unsigned(ADDR_SIZE downto 0);
    signal   WRITE_ADDR     : unsigned(ADDR_SIZE downto 0);
    signal   OUTPUT         : std_logic_vector(R_DATA'range);
    signal   IS_FULL_MEM    : std_logic;
begin
    regFile : process (CLK) is
    begin
        if rising_edge(CLK) then 
            if RST = '1' then
                for I in 0 to DEPTH-1 loop
                    registers(I) <= std_logic_vector(to_unsigned(0, R_DATA'length));
                end loop;
                READ_ADDR   <= to_unsigned(0, READ_ADDR'length);
                WRITE_ADDR  <= to_unsigned(0, WRITE_ADDR'length);
                OUTPUT      <= (others => '0');
                IS_FULL_MEM <= '0';
            else
                -- This accounts for the case that the FIFO is full, that is 
                -- that the write address is one less than the read address
                if W_EN = '1' and R_EN = '0' and
                    ((WRITE_ADDR = (READ_ADDR - to_unsigned(1, READ_ADDR'length))) 
                    or (READ_ADDR = to_unsigned(0, READ_ADDR'length) 
                    and WRITE_ADDR = to_unsigned(DEPTH-1, WRITE_ADDR'length))
                ) 
                then
                    IS_FULL_MEM <= '1';
                elsif W_EN = '0' and R_EN = '1' then
                    IS_FULL_MEM <= '0';
                else
                    IS_FULL_MEM <= IS_FULL_MEM;
                end if;

                -- Handle the write enable line
                if W_EN = '1' then
                    if (IS_FULL_MEM = '0' or R_EN = '1') and WRITE_ADDR < to_unsigned(DEPTH, WRITE_ADDR'length) then
                        registers(to_integer(WRITE_ADDR)) <= W_DATA;
                    end if;
                    
                    if IS_FULL_MEM = '0' or R_EN = '1' then
                        if WRITE_ADDR >= to_unsigned(DEPTH-1, WRITE_ADDR'length) then
                            WRITE_ADDR <= to_unsigned(0, WRITE_ADDR'length);
                        else
                            WRITE_ADDR <= WRITE_ADDR + to_unsigned(1, WRITE_ADDR'length);
                        end if;
                    else
                        WRITE_ADDR <= WRITE_ADDR;
                    end if; 
                end if; 

                -- Handle the read enable line
                if R_EN = '1' then
                    if((READ_ADDR = WRITE_ADDR) and (IS_FULL_MEM = '0')) then
                        OUTPUT <= std_logic_vector(to_unsigned(0, R_DATA'length));
                    elsif READ_ADDR < to_unsigned(DEPTH, READ_ADDR'length) then
                        OUTPUT <= registers(to_integer(READ_ADDR));
                    else
                        OUTPUT <= OUTPUT;
                    end if;

                    if(READ_ADDR = WRITE_ADDR) and (IS_FULL_MEM = '0') then
                        READ_ADDR <= READ_ADDR;
                    elsif READ_ADDR >= to_unsigned(DEPTH-1, READ_ADDR'length) then
                        READ_ADDR <= to_unsigned(0, READ_ADDR'length);
                    else
                        READ_ADDR <= READ_ADDR + to_unsigned(1, READ_ADDR'length);
                    end if;
                end if;
            end if;
        end if;    
    end process;

    HAS_DATA <= '0' when (READ_ADDR = WRITE_ADDR) and (IS_FULL_MEM = '0') else '1';
    IS_FULL  <= IS_FULL_MEM;

    R_DATA <= OUTPUT;
end sim;
