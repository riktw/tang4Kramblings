-- #################################################################################################
-- # << NEORV32 - Machine System Timer (MTIME) >>                                                  #
-- # ********************************************************************************************* #
-- # Compatible to RISC-V spec's 64-bit MACHINE system timer including "mtime[h]" & "mtimecmp[h]". #
-- # Note: The 64-bit counter and compare systems are de-coupled into two 32-bit systems.          #
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
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_mtime is
  port (
    -- host access --
    clk_i  : in  std_ulogic; -- global clock line
    addr_i : in  std_ulogic_vector(31 downto 0); -- address
    rden_i : in  std_ulogic; -- read enable
    wren_i : in  std_ulogic; -- write enable
    data_i : in  std_ulogic_vector(31 downto 0); -- data in
    data_o : out std_ulogic_vector(31 downto 0); -- data out
    ack_o  : out std_ulogic; -- transfer acknowledge
    -- time output for CPU --
    time_o : out std_ulogic_vector(63 downto 0); -- current system time
    -- interrupt --
    irq_o  : out std_ulogic  -- interrupt request
  );
end neorv32_mtime;

architecture neorv32_mtime_rtl of neorv32_mtime is

  -- IO space: module base address --
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(mtime_size_c); -- low address boundary bit

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(31 downto 0); -- access address
  signal wren   : std_ulogic; -- module access enable

  -- time write access buffer --
  signal mtime_lo_we : std_ulogic;
  signal mtime_hi_we : std_ulogic;

  -- accessible regs --
  signal mtimecmp_lo   : std_ulogic_vector(31 downto 0);
  signal mtimecmp_hi   : std_ulogic_vector(31 downto 0);
  signal mtime_lo      : std_ulogic_vector(31 downto 0);
  signal mtime_lo_nxt  : std_ulogic_vector(32 downto 0);
  signal mtime_lo_ovfl : std_ulogic_vector(00 downto 0);
  signal mtime_hi      : std_ulogic_vector(31 downto 0);

  -- comparator and IRQ trigger --
  signal cmp_lo       : std_ulogic;
  signal cmp_lo_ff    : std_ulogic;
  signal cmp_hi       : std_ulogic;
  signal cmp_match_ff : std_ulogic;

begin

  -- Access Control -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = mtime_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= mtime_base_c(31 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 2) & "00"; -- word aligned
  wren   <= acc_en and wren_i;


  -- Write Access ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  wr_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      -- mtimecmp --
      if (wren = '1') then
        if (addr = mtime_cmp_lo_addr_c) then
          mtimecmp_lo <= data_i;
        end if;
        if (addr = mtime_cmp_hi_addr_c) then
          mtimecmp_hi <= data_i;
        end if;
      end if;

      -- mtime access buffer --
--    wdata_buf   <= data_i; -- not required, CPU wdata is stable until transfer is acknowledged
      mtime_lo_we <= wren and bool_to_ulogic_f(boolean(addr = mtime_time_lo_addr_c));
      mtime_hi_we <= wren and bool_to_ulogic_f(boolean(addr = mtime_time_hi_addr_c));

      -- mtime low --
      if (mtime_lo_we = '1') then -- write access
        mtime_lo <= data_i;
      else -- auto increment
        mtime_lo <= mtime_lo_nxt(31 downto 0);
      end if;
      mtime_lo_ovfl(0) <= mtime_lo_nxt(32); -- overflow (carry)

      -- mtime high --
      if (mtime_hi_we = '1') then -- write access
        mtime_hi <= data_i;
      else -- auto increment (if mtime.low overflows)
        mtime_hi <= std_ulogic_vector(unsigned(mtime_hi) + unsigned(mtime_lo_ovfl));
      end if;
    end if;
  end process wr_access;

  -- mtime.time_LO increment --
  mtime_lo_nxt <= std_ulogic_vector(unsigned('0' & mtime_lo) + 1);


  -- Read Access ----------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  rd_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      ack_o  <= acc_en and (rden_i or wren_i);
      data_o <= (others => '0'); -- default
      if (rden_i = '1') and (acc_en = '1') then
        case addr is
          when mtime_time_lo_addr_c => -- mtime LOW
            data_o <= mtime_lo;
          when mtime_time_hi_addr_c => -- mtime HIGH
            data_o <= mtime_hi;
          when mtime_cmp_lo_addr_c => -- mtimecmp LOW
            data_o <= mtimecmp_lo;
          when others => -- mtime_cmp_hi_addr_c -- mtimecmp HIGH
            data_o <= mtimecmp_hi;
        end case;
      end if;
    end if;
  end process rd_access;

  -- system time output for cpu --
  time_o <= mtime_hi & mtime_lo;


  -- Comparator -----------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  cmp_sync: process(clk_i)
  begin
    if rising_edge(clk_i) then
      cmp_lo_ff    <= cmp_lo;
      cmp_match_ff <= cmp_lo_ff and cmp_hi;
      irq_o        <= cmp_lo_ff and cmp_hi and (not cmp_match_ff);
    end if;
  end process cmp_sync;

  -- test words --
  cmp_lo <= '1' when (unsigned(mtime_lo) >= unsigned(mtimecmp_lo)) else '0';
  cmp_hi <= '1' when (unsigned(mtime_hi) >= unsigned(mtimecmp_hi)) else '0';


end neorv32_mtime_rtl;
