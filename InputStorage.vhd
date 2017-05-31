----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/26/2017 02:46:53 PM
-- Design Name: 
-- Module Name: InputStorage - Behavioral
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity InputStorage is
    Port (
        Clk         : in std_logic;
        new_data    : in std_logic;
        mc_data     : in std_logic_vector(39 downto 0);
        
        clear       : in std_logic;
        
        purge       : in std_logic;
        out_data    : out std_logic_vector(39 downto 0);
        empty       : out std_logic
    );
end InputStorage;

architecture Behavioral of InputStorage is

type array_type is array (0 to 7) of std_logic_vector(39 downto 0);
signal storage : array_type := (others => (others => '0'));

signal count : unsigned(2 downto 0) := "000";                       -- how many do we have now
signal is_empty : std_logic := '1';

begin

Main: process(Clk)
begin
    if rising_edge(Clk) then
        if clear = '1' then
            storage <= (others => (others => '0'));
        elsif new_data = '1' then
            storage(7) <= storage(6);
            storage(6) <= storage(5);
            storage(5) <= storage(4);
            storage(4) <= storage(3);
            storage(3) <= storage(2);
            storage(2) <= storage(1);
            storage(1) <= storage(0);
            storage(0) <= mc_data;
            if count < 7 then
                count <= count + 1;
                is_empty <= '0';
            end if;
        elsif purge = '1' then
            out_data <= storage(to_integer(count));
            storage(to_integer(count)) <= (others => '0');
            if count > 0 then
                count <= count - 1;
            elsif count = 0 then
                is_empty <= '1';
            end if;
        end if;
    end if;
end process Main;

empty <= is_empty;

end Behavioral;
