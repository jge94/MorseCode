----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Tao Wang
-- 
-- Create Date: 05/17/2017 10:51:43 PM
-- Design Name: 
-- Module Name: SerialRx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity SerialRx is
  Port (    Clk         : in std_logic;
            RsRx        : in std_logic;
            ena         : in std_logic;
--            rx_shift    : out std_logic;
            rx_data     : out std_logic_vector(7 downto 0);
            rx_done_tick: out std_logic);
end SerialRx;

architecture Behavioral of SerialRx is

signal fpfp1 : std_logic := '1';
signal fpfp2 : std_logic := '1';

signal shift_reg : std_logic_vector(9 downto 0) := (others => '0');
signal paral_reg : std_logic_vector(7 downto 0) := (others => '0');
signal clear : std_logic := '0';
signal shift : std_logic := '0';
signal load : std_logic := '0';

-- N = clock frequency / baud rate = 10000000 / 115200, seven bits
constant N : integer := 10000000/115200 - 1;
constant halfN : integer := N/2;
signal isfirst : std_logic := '1';
signal counter : unsigned(6 downto 0) := (others => '0');
signal bits : unsigned(3 downto 0) := "0000";

type state_type is (stop, count, shifting, done);
signal current_state, next_state : state_type := stop;
signal done_tick : std_logic := '0';
signal running : std_logic := '0';

begin

Synchronizer: process(Clk)
begin
    if rising_edge(Clk) then
        if ena = '1' then
            fpfp1 <= RsRx;
            fpfp2 <= fpfp1;
        end if;
    end if;
end process Synchronizer;

Registers: process(Clk)
begin
    if rising_edge(Clk) then
        -- shift register
        if clear = '1' then
            shift_reg <= (others => '0');
            bits <= (others => '0');
        elsif shift = '1' then
            shift_reg <= fpfp2 & shift_reg(9 downto 1);
            bits <= bits + 1;
            isfirst <= '0';
        end if;
        
        -- parallel register
        if load = '1' then
            paral_reg <= shift_reg(8 downto 1);
            isfirst <= '1';
        end if;
    end if;
end process Registers;

Counting: process(Clk)
begin
    if rising_edge(Clk) then
        if running = '1' then
            if isfirst = '1' then
                if counter < halfN then
                    counter <= counter + 1;
                else
                    counter <= (others => '0');
                end if;
            else
                if counter < N then
                    counter <= counter + 1;
                else
                    counter <= (others => '0');
                end if;
            end if;
        else
            counter <= (others => '0');
        end if;
    end if;
end process Counting;

StateMachine: process(fpfp2, counter, bits, current_state, isfirst)
begin
    shift <= '0';
    clear <= '0';
    load <= '0';
    done_tick <= '0';
    running <= '0';
    next_state <= current_state;
    case (current_state) is
    when stop =>
        clear <= '1';
        if fpfp2 = '0' then
            running <= '1';
            next_state <= count;
        end if;
    
    when count =>
        running <= '1';
        if isfirst = '1' then
            if counter >= halfN then
                next_state <= shifting;
            end if;
        else
            if bits >= "1010" then
                next_state <= done;
            elsif counter >= N then
                next_state <= shifting;
            end if;
        end if;
    
    when shifting =>
        shift <= '1';
        next_state <= count;
    
    when done =>
        running <= '0';
        load <= '1';
        done_tick <= '1';
        clear <= '1';
        next_state <= stop;
        
    when others => next_state <= stop;
    
    end case;
    
end process StateMachine;

StateUpdate: process(Clk)
begin
    if rising_edge(Clk) then
        current_state <= next_state;
    end if;
end process StateUpdate;

rx_done_tick <= done_tick;
--rx_shift <= shift;                      -- TODO: remove, debug only
rx_data <= paral_reg;

end Behavioral;
