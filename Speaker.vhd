----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/26/2017 07:52:34 PM
-- Design Name: 
-- Module Name: speaker - Behavioral
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

library UNISIM;					-- needed for the BUFG component
use UNISIM.Vcomponents.all;

entity Speaker is
    Port ( enable : in std_logic;
           clk : in std_logic;
           sound : out std_logic;
           gain : out std_logic;
           turnon : out std_logic);
end Speaker;

architecture Behavioral of Speaker is
signal sound_effect : std_logic := '0';
signal prev_enable : std_logic := '0';

-- Signals for the 10 MHz to 1kHz clock divider
constant CLOCK_DIVIDER_VALUE : integer := 5000;
signal clkdiv : integer := 0;			-- the clock divider counter
signal clk_en : std_logic := '0';		-- terminal count
signal clk1k : std_logic;				-- 1 kHz clock signal

begin

SlowClockBuffer: BUFG
      port map (I => clk_en,
                O => clk1k);

ClockDivider: process(clk)
begin
    if rising_edge(clk) then
           if clkdiv = CLOCK_DIVIDER_VALUE - 1 then 
               clk_en <= NOT(clk_en);        
            clkdiv <= 0;
        else
            clkdiv <= clkdiv + 1;
        end if;
    end if;
end process ClockDivider;

Audio: process (clk1k)
begin    
    sound_effect <= enable and clk1k;
end process audio;

sound <= sound_effect;
gain <= '1';
turnon <= '1';

end Behavioral;
