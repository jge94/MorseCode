----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Tao Wang
-- 
-- Create Date: 05/21/2017 10:58:32 PM
-- Design Name: 
-- Module Name: mc_top - Behavioral
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
use IEEE.numeric_std.all;

library UNISIM;					-- needed for the BUFG component
use UNISIM.Vcomponents.all;

entity mc_top is
  Port (    mclk    : in std_logic;     -- FPGA clock
            RsRx    : in std_logic;     -- Serial keyboard input
            RsTx    : out std_logic;    -- Serial output loopback
            
            -- display
            flush   : in std_logic;     -- display
            led     : out std_logic_vector(15 downto 0);
            
            seg     : out std_logic_vector(0 to 6);
            dp      : out std_logic;
            an      : out std_logic_vector(3 downto 0);
            
            sound   : out std_logic;
            gain    : out std_logic;
            turnon  : out std_logic);
end mc_top;

architecture Behavioral of mc_top is

-- COMPONENTS
component mux7seg is
    Port (  clk             : in std_logic;
            y0, y1, y2, y3  : in std_logic_vector(3 downto 0);
            dp_set          : in std_logic_vector(3 downto 0);
            seg             : out std_logic_vector(0 to 6);
            dp              : out std_logic;
            an              : out std_logic_vector(3 downto 0));
end component;

component Speaker is
    Port (  enable          : in std_logic;
            clk             : in std_logic;
            sound           : out std_logic;
            gain            : out std_logic;
            turnon          : out std_logic);
end component;

component mc_mem is
    Port (  clka        : in std_logic;
            ena         : in std_logic;
            addra       : in std_logic_vector(5 downto 0);
            douta       : out std_logic_vector(31 downto 0));
end component;

component disp_mem is
    Port (  clka        : in std_logic;
            ena         : in std_logic;
            addra       : in std_logic_vector(5 downto 0);
            douta       : out std_logic_vector(39 downto 0));
end component;

component InputStorage is
    Port (
        Clk         : in std_logic;
        new_data    : in std_logic;
        mc_data     : in std_logic_vector(39 downto 0);
        clear       : in std_logic;
        purge       : in std_logic;
        out_data    : out std_logic_vector(39 downto 0);
        empty       : out std_logic);
end component;

component SerialRx is
    Port (  Clk         : in std_logic;
            RsRx        : in std_logic;
            ena         : in std_logic;
            rx_data     : out std_logic_vector(7 downto 0);
            rx_done_tick: out std_logic);
end component;

component SerialTx is
    Port (  Clk         : in  std_logic;
            tx_data     : in  std_logic_vector (7 downto 0);
            tx_start    : in  std_logic;
            tx          : out  std_logic;                        -- to RS-232 interface
            tx_done_tick: out  std_logic);
end component;

-- Signals for the 100 MHz to 10 MHz clock divider
constant CLOCK_DIVIDER_VALUE : integer := 5;
signal clkdiv : integer := 0;			-- the clock divider counter
signal clk_en : std_logic := '0';		-- terminal count
signal clk10 : std_logic;				-- 10 MHz clock signal

signal input_data : std_logic_vector(7 downto 0) := (others => '0');
signal new_input : std_logic := '0';

signal lookup_addr : std_logic_vector(7 downto 0) := (others => '1');
signal morse_path : std_logic_vector(31 downto 0) := (others => '0');           -- look at this to make light and sound

type state_type is (waiting, counting, shining, darkness, flushing, sending);
signal current_state, next_state : state_type := waiting;

signal enable_rx : std_logic := '1';                                            -- whether to get the next input

-- display
signal light : std_logic := '0';
signal next_bit : std_logic := '0';
signal clear_bits : std_logic := '0';
signal bit_count : unsigned(4 downto 0) := (others => '1');                         -- digit counter, 1 light, 0 no light

signal next_light : std_logic := '0';
signal clear_light : std_logic := '0';
signal light_count : unsigned(23 downto 0) := (others => '0');                      -- how long a light section is
constant LIGHT_LENGTH : integer := 2000000;
--constant LIGHT_LENGTH : integer := 1000;                                            -- simulation only

-- workaround for the slow update of morse_path
signal new_input_b1 : std_logic := '0';
signal new_input_b2 : std_logic := '0';
signal new_input_b3 : std_logic := '0';
signal new_input_b4 : std_logic := '0';
signal prev_input_b4 : std_logic := '0';

-- send back data
signal send_back : std_logic := '0';        -- start sending back
signal prepare_send_back : std_logic := '0';-- buffer
signal done_send_back : std_logic := '0';   -- done sending back
signal has_done_sent : std_logic := '1';    -- buffered
signal send_back_data : std_logic_vector(7 downto 0) := (others => '1');
signal sending_bit : unsigned(2 downto 0) := "000"; -- which digit to send, not really bit
signal clear_send_bit : std_logic := '0';           -- reset send bit to 0
signal prev_flush : std_logic := '0';
signal flush_output : std_logic_vector(39 downto 0) := (others => '1');                   -- dashes and dots

-- data storage
signal save_data : std_logic := '0';
signal save_output : std_logic_vector(39 downto 0) := (others => '0');                      -- what to put into storage
signal clear_storage : std_logic := '0';
signal purge : std_logic := '0';
signal is_empty : std_logic := '1';

begin

SlowClockBuffer: BUFG
      port map (I => clk_en,
                O => clk10);

ClockDividerMain: process(mclk)
begin
	if rising_edge(mclk) then
	   	if clkdiv = CLOCK_DIVIDER_VALUE - 1 then 
	   		clk_en <= NOT(clk_en);		
			clkdiv <= 0;
		else
			clkdiv <= clkdiv + 1;
		end if;
	end if;
end process ClockDividerMain;

-- Business Logic
PathFinder: process(clk10)
begin
    if rising_edge(clk10) then
        if unsigned(input_data) >= 97 and unsigned(input_data) <= 122 then
            lookup_addr <= std_logic_vector(unsigned(input_data) - 97);
        elsif unsigned(input_data) >= 65 and unsigned(input_data) <= 90 then
            lookup_addr <= std_logic_vector(unsigned(input_data) - 65);
        elsif unsigned(input_data) >= 48 and unsigned(input_data) <= 57 then
            lookup_addr <= std_logic_vector(unsigned(input_data) - 22);
        else
            lookup_addr <= (others => '1');
        end if;
    end if;
end process PathFinder;

-- Business Logic

BitCounter: process(clk10)
begin
    if rising_edge(clk10) then
        if clear_bits = '1' then
            bit_count <= (others => '1');
        elsif next_bit = '1' then
            bit_count <= bit_count - 1;
        end if;
    end if;
end process BitCounter;

LightCounter: process(clk10)
begin
    if rising_edge(clk10) then
        if clear_light = '1' then
            light_count <= (others => '0');
        elsif next_light = '1' then
            light_count <= light_count + 1;
        end if;
    end if;
end process LightCounter;

NewInputBuffer: process(clk10)
begin
    if rising_edge(clk10) then
        new_input_b1 <= new_input;
        new_input_b2 <= new_input_b1;
        new_input_b3 <= new_input_b2;
        new_input_b4 <= new_input_b3;
        prev_input_b4 <= new_input_b4;
    end if;
end process NewInputBuffer;

StateMachine: process(current_state, new_input_b4, prev_input_b4, morse_path, bit_count, light_count, flush,
                        sending_bit, has_done_sent, prev_flush)
begin
    
    next_state <= current_state;
    enable_rx <= '0';
    
    clear_bits <= '0';
    next_bit <= '0';
    
    clear_light <= '0';
    next_light <= '0';
    
    -- storage
    save_data <= '0';
    clear_storage <= '0';
    purge <= '0';
    
    -- send back
    prepare_send_back <= '0';
    clear_send_bit <= '1';
    next_bit <= '0';
    
    case (current_state) is
        when waiting =>
            light <= '0';
            enable_rx <= '1';
            clear_bits <= '1';
            if new_input_b4 = '1' and prev_input_b4 = '0' then
                next_state <= counting;
                save_data <= '1';
            elsif flush = '1' and prev_flush = '0' then
                next_state <= flushing;
            end if;
            
        when counting =>
            next_bit <= '1';
            if morse_path(to_integer(bit_count)) = '0' and morse_path(to_integer(bit_count - 1)) = '0' then
                -- previous zero & current zero
                next_state <= waiting;
            elsif morse_path(to_integer(bit_count)) = '1' then
                next_state <= shining;
            else
                next_state <= darkness;
            end if;
        
        when shining =>
            light <= '1';
            next_light <= '1';
            if light_count >= LIGHT_LENGTH then
                next_state <= counting;
                clear_light <= '1';
            end if;
            
        when darkness =>
            light <= '0';
            next_light <= '1';
            if light_count >= LIGHT_LENGTH then
                next_state <= counting;
                clear_light <= '1';
            end if;
        
        when flushing =>
            light <= '0';
            if is_empty = '1' then
                next_state <= waiting;
            else
                purge <= '1';
                next_state <= sending;
            end if;
        
        when sending =>
            light <= '0';
            clear_send_bit <= '0';
            
            if has_done_sent = '1' then
                if sending_bit < 5 then
                    prepare_send_back <= '1';
                    next_bit <= '1';
                else
                    next_state <= flushing;
                end if;
            end if;
        
        when others => next_state <= waiting;
    end case;
    
end process StateMachine;

SendData: process(clk10)
begin
    if rising_edge(clk10) then
        if prepare_send_back = '1' then
            if sending_bit = "000" then
                send_back_data <= flush_output(39 downto 32);
            elsif sending_bit = "001" then
                send_back_data <= flush_output(31 downto 24);
            elsif sending_bit = "010" then
                send_back_data <= flush_output(23 downto 16);
            elsif sending_bit = "011" then
                send_back_data <= flush_output(15 downto 8);
            elsif sending_bit = "100" then
                send_back_data <= flush_output(7 downto 0);
            else
                send_back_data <= "00100000";               -- space
            end if;
        end if;
    end if;
end process SendData;

FlushBuffer: process(clk10)
begin
    if rising_edge(clk10) then
        prev_flush <= flush;
    end if;
end process FlushBuffer;

SendCounter: process(clk10)
begin
    if rising_edge(clk10) then
        if clear_send_bit = '1' then
            sending_bit <= "000";
        elsif next_bit = '1' then
            sending_bit <= sending_bit + 1;
        end if;
    end if;
end process SendCounter;

DoneSend: process(clk10)
begin
    if rising_edge(clk10) then
        if done_send_back = '1' then
            has_done_sent <= '1';
        elsif prepare_send_back = '1' then
            has_done_sent <= '0';
        end if;
    end if;
end process DoneSend;

SendBack: process(clk10)
begin
    if rising_edge(clk10) then
        send_back <= prepare_send_back;
    end if;
end process SendBack;

StateUpdate: process(clk10)
begin
    if rising_edge(clk10) then
        current_state <= next_state;
    end if;
end process StateUpdate;


-- Components mapping
Receiver: SerialRx port map (
    Clk => clk10,
    RsRx => RsRx,
    ena => enable_rx,
    rx_data => input_data,
    rx_done_tick => new_input);

Transmitter: SerialTx port map (
    Clk => clk10,
    tx_data => send_back_data,                      -- TODO: change to actual output later
--    tx_start => new_input,                      -- TODO: see ^
    tx_start => send_back,
    tx => RsTx,
    tx_done_tick => done_send_back);

MorseMemory: mc_mem port map (
    clka => clk10,
    ena => '1',
    addra => lookup_addr(5 downto 0),
    douta => morse_path);

DisplayMemory: disp_mem port map (
    clka => clk10,
    ena => '1',
    addra => lookup_addr(5 downto 0),
    douta => save_output);

StorageDevice: InputStorage port map (
    Clk => clk10,
    new_data => save_data,
    mc_data => save_output,
    clear => clear_storage,
    purge => purge,
    out_data => flush_output,
    empty => is_empty);

AsciiDisplay: mux7seg port map (
    clk => clk10,
--    y0 => morse_path(19 downto 16),
--    y1 => morse_path(23 downto 20),
--    y2 => morse_path(27 downto 24),
--    y3 => morse_path(31 downto 28),
    y0 => save_output(11 downto 8),
    y1 => save_output(19 downto 16),
    y2 => save_output(27 downto 24),
    y3 => save_output(35 downto 32),
    dp_set => "0000",
    seg => seg,
    dp => dp,
    an => an);

SoundDevice: Speaker port map (
    enable => light,
    clk => clk10,
    sound => sound,
    gain => gain,
    turnon => turnon);

led <= (others => light);


end Behavioral;
