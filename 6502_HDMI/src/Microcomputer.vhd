-- This file is copyright by Grant Searle 2014
-- You are free to use this file in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the "multicomp" page at http://searle.hostei.com/grant/Multicomp/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity Microcomputer is
	port(
		n_reset		: in std_logic;
		clk			: in std_logic;

        hdmi_tx_clk_n   : out std_logic;
        hdmi_tx_clk_p   : out std_logic;
        hdmi_tx_n       : out std_logic_vector(2 downto 0);
        hdmi_tx_p       : out std_logic_vector(2 downto 0);

		ps2Clk		: inout std_logic;
		ps2Data		: inout std_logic;

		driveLED		: out std_logic :='1'	
	);
end Microcomputer;

architecture struct of Microcomputer is

	signal n_WR							: std_logic;
	signal n_RD							: std_logic;
	signal cpuAddress					: std_logic_vector(15 downto 0);
	signal cpuDataOut					: std_logic_vector(7 downto 0);
	signal cpuDataIn					: std_logic_vector(7 downto 0);

	signal basRomData					: std_logic_vector(7 downto 0);
	signal internalRam1DataOut		: std_logic_vector(7 downto 0);
	signal internalRam2DataOut		: std_logic_vector(7 downto 0);
	signal interface1DataOut		: std_logic_vector(7 downto 0);
	signal interface2DataOut		: std_logic_vector(7 downto 0);
	signal sdCardDataOut				: std_logic_vector(7 downto 0);

	signal n_memWR						: std_logic :='1';
	signal n_memRD 					: std_logic :='1';

	signal n_ioWR						: std_logic :='1';
	signal n_ioRD 						: std_logic :='1';
	
	signal n_MREQ						: std_logic :='1';
	signal n_IORQ						: std_logic :='1';	

	signal n_int1						: std_logic :='1';	
	signal n_int2						: std_logic :='1';	
	
	signal n_externalRamCS			: std_logic :='1';
	signal n_internalRam1CS			: std_logic :='1';
	signal n_internalRam2CS			: std_logic :='1';
	signal n_basRomCS					: std_logic :='1';
	signal n_interface1CS			: std_logic :='1';
	signal n_interface2CS			: std_logic :='1';
	signal n_sdCardCS					: std_logic :='1';

	signal serialClkCount			: std_logic_vector(15 downto 0);
	signal cpuClkCount				: std_logic_vector(5 downto 0); 
	signal sdClkCount					: std_logic_vector(5 downto 0); 	
	signal cpuClock					: std_logic;
	signal serialClock				: std_logic;
	signal sdClock						: std_logic;	

    signal videoR0      : std_logic;
    signal videoR1      : std_logic;
    signal videoG0      : std_logic;
    signal videoG1      : std_logic;
    signal videoB0      : std_logic;
    signal videoB1      : std_logic;
    signal videoR       : std_logic_vector(7 downto 0) := "00000000";
    signal videoG       : std_logic_vector(7 downto 0) := "00000000";
    signal videoB       : std_logic_vector(7 downto 0) := "00000000";
    signal hSync        : std_logic;
    signal vSync        : std_logic;

    signal uartrx       : std_logic;
    signal uarttx       : std_logic;
    signal rts1         : std_logic;

    signal dviclk       : std_logic;
    signal vgaclk       : std_logic;
    signal framestart   : std_logic;

	
begin
-- ____________________________________________________________________________________
-- CPU CHOICE GOES HERE
cpu1 : entity work.T65
port map(
    Enable => '1',
    Mode => "00",
    Res_n => n_reset,
    Clk => cpuClock,
    Rdy => '1',
    Abort_n => '1',
    IRQ_n => '1',
    NMI_n => '1',
    SO_n => '1',
    R_W_n => n_WR,
    A(15 downto 0) => cpuAddress,
    DI => cpuDataIn,
    DO => cpuDataOut
);
-- ____________________________________________________________________________________
-- ROM GOES HERE	
rom1 : entity work.basicRom -- 8KB BASIC
port map(
    ad => cpuAddress(12 downto 0),
    clk => clk,
    dout => basRomData,
    reset => '0',
    ce => '1',
    oce => '1'
);
-- ____________________________________________________________________________________
-- RAM GOES HERE
ram1: entity work.Gowin_SP
port map
(
    ad => cpuAddress(11 downto 0),
    clk => clk,
    din => cpuDataOut,
    wre => not(n_memWR or n_internalRam1CS),
    dout => internalRam1DataOut,
    reset => '0',
    ce => '1',
    oce => '1'
);
-- ____________________________________________________________________________________
-- INPUT/OUTPUT DEVICES GO HERE	

io1 : entity work.bufferedUART
port map(
    clk => clk,
    n_wr => n_interface1CS or cpuClock or n_WR,
    n_rd => n_interface1CS or cpuClock or (not n_WR),
    n_int => n_int1,
    regSel => cpuAddress(0),
    dataIn => cpuDataOut,
    dataOut => interface1DataOut,
    rxClock => serialClock,
    txClock => serialClock,
    rxd => uartrx,
    txd => uarttx,
    n_cts => '0',
    n_dcd => '0',
    n_rts => rts1
);

pll50 : entity work.pll50
port map (
    clkout => vgaclk,
    clkin => dviclk
);

vt521 : entity work.vt52
port map (
    clk => vgaclk,
    start => framestart,
    hsync => hSync,
    vsync => vSync,
    video => videoG0,
    ps2_data => ps2Data,
    ps2_clk => ps2Clk,
    rxd => uarttx,
    txd => uartrx
);

videoG  <= "11111111" when videoG0 = '1' else "00000000";

-- more video 
dvi1 : entity work.display_dvi
port map
(
    CLK => clk,
    RST_BTN => n_reset,
    hdmi_tx_clk_n => hdmi_tx_clk_n,
    hdmi_tx_clk_p => hdmi_tx_clk_p,
    hdmi_tx_n => hdmi_tx_n,
    hdmi_tx_p => hdmi_tx_p,

    red => "00000000",
    green => videoG,
    blue => "00100000",
    dviclk => dviclk,
    framestart => framestart
);
-- ____________________________________________________________________________________
-- MEMORY READ/WRITE LOGIC GOES HERE
n_memRD <= not(cpuClock) nand n_WR;
n_memWR <= not(cpuClock) nand (not n_WR);
-- ____________________________________________________________________________________
-- CHIP SELECTS GO HERE

n_basRomCS <= '0' when cpuAddress(15 downto 13) = "111" else '1'; --8K at top of memory
n_interface1CS <= '0' when cpuAddress(15 downto 1) = "111111111101000" else '1'; -- 2 bytes FFD0-FFD1
n_interface2CS <= '0' when cpuAddress(15 downto 1) = "111111111101001" else '1'; -- 2 bytes FFD2-FFD3
n_sdCardCS <= '0' when cpuAddress(15 downto 3) = "1111111111011" else '1'; -- 8 bytes FFD8-FFDF
n_internalRam1CS <= '0' when cpuAddress(15 downto 12) = "0000" else '1';    -- 4K internal RAM
-- ____________________________________________________________________________________
-- BUS ISOLATION GOES HERE
cpuDataIn <=
interface1DataOut when n_interface1CS = '0' else
interface2DataOut when n_interface2CS = '0' else
sdCardDataOut when n_sdCardCS = '0' else
basRomData when n_basRomCS = '0' else
internalRam1DataOut when n_internalRam1CS= '0' else
x"FF";
-- ____________________________________________________________________________________
-- SYSTEM CLOCKS GO HERE
serialClock <= serialClkCount(15);
process (clk)
begin
if rising_edge(clk) then

    if cpuClkCount < 4 then -- 4 = 10MHz, 3 = 12.5MHz, 2=16.6MHz, 1=25MHz
        cpuClkCount <= cpuClkCount + 1;
    else
        cpuClkCount <= (others=>'0');
    end if;

    if cpuClkCount < 2 then -- 2 when 10MHz, 2 when 12.5MHz, 2 when 16.6MHz, 1 when 25MHz
        cpuClock <= '0';
    else
        cpuClock <= '1';
    end if;

    if sdClkCount < 49 then -- 1MHz
        sdClkCount <= sdClkCount + 1;
    else
        sdClkCount <= (others=>'0');
    end if;

    if sdClkCount < 25 then
        sdClock <= '0';
    else
        sdClock <= '1';
    end if;

    -- Serial clock DDS
    -- 50MHz master input clock:
    -- Baud Increment
    -- 115200 2416
    -- 38400 805
    -- 19200 403
    -- 9600 201
    -- 4800 101
    -- 2400 50
    serialClkCount <= serialClkCount + 4474;  -- 27Mhz
end if;
end process;
end;
