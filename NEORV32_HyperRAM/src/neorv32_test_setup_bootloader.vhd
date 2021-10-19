-- #################################################################################################
-- # << NEORV32 - Test Setup using the UART-Bootloader to upload and run executables >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32                           #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_test_setup_bootloader is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   : natural := 54000000; -- clock frequency of clk_i in Hz
    MEM_INT_IMEM_SIZE : natural := 8*1024;   -- size of processor-internal instruction memory in bytes
    MEM_INT_DMEM_SIZE : natural := 8*1024     -- size of processor-internal data memory in bytes
  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- GPIO --
    gpio_o      : out std_ulogic_vector(7 downto 0); -- parallel output
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic;  -- UART0 receive data
    
    O_hpram_ck      : out std_logic_vector(0 downto 0);
    O_hpram_ck_n    : out std_logic_vector(0 downto 0);
    O_hpram_cs_n    : out std_logic_vector(0 downto 0);
    O_hpram_reset_n : out std_logic_vector(0 downto 0);
    IO_hpram_dq     : inout std_logic_vector(7 downto 0);
    IO_hpram_rwds   : inout std_logic_vector(0 downto 0)
  );
end entity;

architecture neorv32_test_setup_bootloader_rtl of neorv32_test_setup_bootloader is

  signal con_gpio_o : std_ulogic_vector(63 downto 0);

  signal wb_tag_o  : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_adr_o  : std_ulogic_vector(31 downto 0); -- address
  signal wb_dat_i  : std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
  signal wb_dat_o  : std_ulogic_vector(31 downto 0); -- write data
  signal wb_we_o   : std_ulogic; -- read/write
  signal wb_sel_o  : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_stb_o  : std_ulogic; -- strobe
  signal wb_cyc_o  : std_ulogic; -- valid cycle
  signal wb_lock_o : std_ulogic; -- exclusive access request
  signal wb_ack_i  : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_err_i  : std_ulogic := 'L'; -- transfer error
  
  -- wishbone cfg slave
  signal wb_cfg_tag_o  : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_cfg_adr_o  : std_ulogic_vector(31 downto 0); -- address
  signal wb_cfg_dat_i  : std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
  signal wb_cfg_dat_o  : std_ulogic_vector(31 downto 0); -- write data
  signal wb_cfg_we_o   : std_ulogic; -- read/write
  signal wb_cfg_sel_o  : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_cfg_stb_o  : std_ulogic; -- strobe
  signal wb_cfg_cyc_o  : std_ulogic; -- valid cycle
  signal wb_cfg_lock_o : std_ulogic; -- exclusive access request
  signal wb_cfg_ack_i  : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_cfg_err_i  : std_ulogic := 'L'; -- transfer error
  
  -- wishbone hyperbus slave
  signal wb_hb_tag_o  : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_hb_adr_o  : std_ulogic_vector(31 downto 0); -- address
  signal wb_hb_dat_i  : std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
  signal wb_hb_dat_o  : std_ulogic_vector(31 downto 0); -- write data
  signal wb_hb_we_o   : std_ulogic; -- read/write
  signal wb_hb_sel_o  : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_hb_stb_o  : std_ulogic; -- strobe
  signal wb_hb_cyc_o  : std_ulogic; -- valid cycle
  signal wb_hb_lock_o : std_ulogic; -- exclusive access request
  signal wb_hb_ack_i  : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_hb_err_i  : std_ulogic := 'L'; -- transfer error
  
  signal hb_clk_o     : std_logic;
  signal hb_cs_o      : std_logic;
  signal hb_rwds_o    : std_logic;
  signal hb_rwds_i    : std_logic;
  signal hb_rwds_dir  : std_logic;
  signal hb_dq_o      : std_logic_vector(7 downto 0);
  signal hb_dq_i      : std_logic_vector(7 downto 0);
  signal hb_dq_dir    : std_logic;
  signal hb_rst_o     : std_logic;
  signal sump_dbg     : std_logic_vector(7 downto 0);

  signal hsclk        : std_logic;
  signal hpram_ck     : std_logic;
  signal rst          : std_logic;


begin

  Gowin_pll : entity work.Gowin_PLLVR
  port map
  (
    clkout => hsclk,
    clkin => clk_i
  );

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN            => true,              -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C        => false,             -- implement compressed extension?
    CPU_EXTENSION_RISCV_M        => false,             -- implement mul/div extension?
    CPU_EXTENSION_RISCV_Zicsr    => true,              -- implement CSR system?
    CPU_EXTENSION_RISCV_E        => true,
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => true,              -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE, -- size of processor-internal instruction memory in bytes
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes
    -- Processor peripherals --
    IO_GPIO_EN                   => true,              -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_EN                  => true,              -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,              -- implement primary universal asynchronous receiver/transmitter (UART0)?
    MEM_EXT_EN                   => true,
    MEM_EXT_PIPE_MODE            => true
  )
  port map (
    -- Global control --
    clk_i       => hsclk,       -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o      => con_gpio_o,  -- parallel output
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i,  -- UART0 receive data

    wb_tag_o  => wb_tag_o,    
    wb_adr_o  => wb_adr_o,   
    wb_dat_i  => wb_dat_i,   
    wb_dat_o  => wb_dat_o,     
    wb_we_o   => wb_we_o,       
    wb_sel_o  => wb_sel_o,    
    wb_stb_o  => wb_stb_o,      
    wb_cyc_o  => wb_cyc_o,     
    wb_lock_o => wb_lock_o,   
    wb_ack_i  => wb_ack_i,     
    wb_err_i  => wb_err_i  
  );
  
  
  -- select bus
  bus_switch: process(hsclk)
  begin
    if rising_edge(hsclk) then
    
      if (wb_adr_o(31 downto 28) = "0001") then --addr 0x1xxxxxxx for cfg
        wb_cfg_tag_o  <= wb_tag_o; 
        wb_cfg_adr_o  <= wb_adr_o;
        wb_dat_i      <= wb_cfg_dat_i; 
        wb_cfg_dat_o  <= wb_dat_o; 
        wb_cfg_we_o   <= wb_we_o;  
        wb_cfg_sel_o  <= wb_sel_o; 
        wb_cfg_stb_o  <= wb_stb_o; 
        wb_cfg_cyc_o  <= wb_cyc_o; 
        wb_cfg_lock_o <= wb_lock_o;
        wb_ack_i      <= wb_cfg_ack_i; 
        wb_err_i      <= wb_cfg_err_i; 
        
        wb_hb_tag_o  <= (others => '0');
        wb_hb_adr_o  <= (others => '0');
        wb_hb_dat_o  <= (others => '0');
        wb_hb_we_o   <= '0';
        wb_hb_sel_o  <= (others => '0');
        wb_hb_stb_o  <= '0';
        wb_hb_cyc_o  <= '0';
        wb_hb_lock_o <= '0';
  
      elsif (wb_adr_o(31 downto 28) = "0010") then  --addr 0x2xxxxxxx for HB
        wb_hb_tag_o  <= wb_tag_o; 
        wb_hb_adr_o  <= wb_adr_o;
        wb_dat_i     <= wb_hb_dat_i; 
        wb_hb_dat_o  <= wb_dat_o; 
        wb_hb_we_o   <= wb_we_o;  
        wb_hb_sel_o  <= wb_sel_o; 
        wb_hb_stb_o  <= wb_stb_o; 
        wb_hb_cyc_o  <= wb_cyc_o; 
        wb_hb_lock_o <= wb_lock_o;
        wb_ack_i     <= wb_hb_ack_i; 
        wb_err_i     <= wb_hb_err_i; 

        wb_cfg_tag_o  <= (others => '0');
        wb_cfg_adr_o  <= (others => '0');
        wb_cfg_dat_o  <= (others => '0');
        wb_cfg_we_o   <= '0';
        wb_cfg_sel_o  <= (others => '0');
        wb_cfg_stb_o  <= '0';
        wb_cfg_cyc_o  <= '0';
        wb_cfg_lock_o <= '0';    
          
      end if;
    
    end if;
  end process;

  O_hpram_ck_n(0) <= '0';


--  ck_obuf: entity work.TLVDS_OBUF
--  port map
-- (
--    O => O_hpram_ck(0),
--    OB => O_hpram_ck_n(0),
--    I => hpram_ck
-- );
  

  rst <= not rstn_i;

  wb_hyperram: entity work.wb_hyper
  port map 
  (
    wb_clk_i => hsclk,
    wb_rst_i => rst,
    wb_dat_i => wb_hb_dat_o,
    wb_dat_o => wb_hb_dat_i,
    wb_adr_i => wb_hb_adr_o,
    wb_sel_i => wb_hb_sel_o,
    wb_cti_i => wb_hb_tag_o,
    wb_we_i  => wb_hb_we_o,
    wb_cyc_i => wb_hb_cyc_o,
    wb_stb_i => wb_hb_stb_o,
    wb_ack_o => wb_hb_ack_i,
    
    wb_cfg_dat_i => wb_cfg_dat_o,
    wb_cfg_dat_o => wb_cfg_dat_i,
    wb_cfg_adr_i => wb_cfg_adr_o,
    wb_cfg_sel_i => wb_cfg_sel_o,
    wb_cfg_we_i  => wb_cfg_we_o,
    wb_cfg_cyc_i => wb_cfg_cyc_o,
    wb_cfg_stb_i => wb_cfg_stb_o,
    wb_cfg_ack_o => wb_cfg_ack_i,
    
    hb_clk_o    => O_hpram_ck(0),   
    hb_cs_o     => O_hpram_cs_n(0),    
    hb_rwds_o   => hb_rwds_o,  
    hb_rwds_i   => hb_rwds_i,  
    hb_rwds_dir => hb_rwds_dir,
    hb_dq_o     => hb_dq_o,    
    hb_dq_i     => hb_dq_i,    
    hb_dq_dir   => hb_dq_dir,  
    hb_rst_o    => O_hpram_reset_n(0),   
    sump_dbg    => sump_dbg   
  );

  bidir_dq: process(hb_dq_dir, IO_hpram_dq, hb_dq_o)
  begin
    if (hb_dq_dir = '1') then
      IO_hpram_dq <= "ZZZZZZZZ";
      hb_dq_i <= IO_hpram_dq;
    else
      IO_hpram_dq <= hb_dq_o;
      hb_dq_i <= IO_hpram_dq;
    end if;
  end process;
  
  bidir_rwds: process(hb_rwds_dir, IO_hpram_rwds, hb_rwds_o)
  begin
    if (hb_rwds_dir = '1') then
      IO_hpram_rwds(0) <= 'Z';
      hb_rwds_i <= IO_hpram_rwds(0);
    else
      IO_hpram_rwds(0) <= hb_rwds_o;
      hb_rwds_i <= IO_hpram_rwds(0);
    end if;
  end process;
  
  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);

end architecture;
