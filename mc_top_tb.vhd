--------------------------------------------------------------------------------
-- Course:
--
-- Create Date:   
-- Design Name:   
-- Module Name:   mc_top_tb.vhd
-- Project Name:  
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: mc_top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:

--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;
 
ENTITY mc_top_tb IS
END mc_top_tb;
 
ARCHITECTURE behavior OF mc_top_tb IS 
 
COMPONENT mc_top
    Port (  mclk    : in std_logic;     -- FPGA clock
            RsRx    : in std_logic;     -- Serial keyboard input
            RsTx    : out std_logic;    -- Serial output loopback
          
            -- display
            flush   : in std_logic;
            seg     : out std_logic_vector(0 to 6);
            dp      : out std_logic;
            an      : out std_logic_vector(3 downto 0));
	END COMPONENT;
   

   --Inputs
   signal mclk : std_logic := '0';
   signal RsRx : std_logic := '1';
   signal RsTx : std_logic;
   signal flush : std_logic := '0';
   signal seg : std_logic_vector(0 to 6);
   signal dp : std_logic;
   signal an : std_logic_vector(3 downto 0);
   

   -- Clock period definitions
   constant clk_period : time := 10ns;		-- 10 MHz clock
	
	-- Data definitions
--	constant bit_time : time := 104us;		-- 9600 baud
	constant bit_time : time := 8.68us;		-- 115,200 baud
	constant TxData : std_logic_vector(7 downto 0) := "01000111";          -- g
	
BEGIN 
	-- Instantiate the Unit Under Test (UUT)
   uut: mc_top PORT MAP (
          mclk => mclk,
          RsRx => RsRx,
          RsTx => RsTx,
          flush => flush,
          seg => seg,
          dp => dp,
          an => an
        );

   -- Clock process definitions
   clk_process :process
   begin
		mclk <= '0';
		wait for clk_period/2;
		mclk <= '1';
		wait for clk_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin		
       wait for 100 us;
       wait for 10.25*clk_period;        
       
       RsRx <= '0';        -- Start bit
       wait for bit_time;
       
       for bitcount in 0 to 7 loop
           RsRx <= TxData(bitcount);
           wait for bit_time;
       end loop;
       
       RsRx <= '1';        -- Stop bit
       wait for 1500 us;
       
       flush <= '1';
       wait for 10.25 * clk_period;
       flush <= '0';
       
       
       
       
--       wait for 700us;
       
--       RsRx <= '0';        -- Start bit
--       wait for bit_time;
       
--       for bitcount in 0 to 7 loop
--           RsRx <= TxData1(bitcount);
--           wait for bit_time;
--       end loop;
       
--       RsRx <= '1';        -- Stop bit
--       wait for 1500 us;
       
--       flush <= '1';
--       wait for 10.25 * clk_period;
--       flush <= '0';
		
		wait;
   end process;
END;
