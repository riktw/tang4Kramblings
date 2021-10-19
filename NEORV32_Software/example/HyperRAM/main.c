// #################################################################################################
// # << NEORV32 - Blinking LED Demo Program >>                                                     #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
// #################################################################################################


/**********************************************************************//**
 * @file blink_led/main.c
 * @author Stephan Nolting
 * @brief Simple blinking LED demo program using the lowest 8 bits of the GPIO.output port.
 **************************************************************************/

#include <neorv32.h>

typedef struct
{
  volatile uint32_t hyperbus_latency_1x;
  volatile uint32_t hyperbus_latency_2x;
  volatile uint32_t hyperbus_cfg_word;
  volatile uint32_t hyperbus_cfg_end;
} HB_Reg;

#define HBConfig      ((HB_Reg*)(0x10000000))

#define BAUD_RATE 19200

    
#define DEEP_PWR_DOWN (15)
#define DRIVE_STRENGTH (12)
#define RESERVED_1 (8)
#define INITIAL_LATENCY (4)
#define FIXED_LATENCY (3)
#define HYBRID_BURST (2)
#define BURST_LENGTH (0)


__attribute__((section(".hyperram"))) uint32_t HyperRAMArray[1024*1024*2]; //2Meg * 4 bytes = 8MB
/**********************************************************************/

int main(void) {
  volatile uint32_t value = 0;
  // setup UART
  neorv32_uart_setup(BAUD_RATE, PARITY_NONE, FLOW_CONTROL_NONE);

  // intro text
  neorv32_uart_print("\nWishbone HyperRAM peripheral config\n");
  
  uint32_t configWord = (1 << DEEP_PWR_DOWN) + (0 << DRIVE_STRENGTH ) + (0xF << RESERVED_1) + (0xE << INITIAL_LATENCY) + (0 << FIXED_LATENCY) + (1 << HYBRID_BURST) + (0x3 << BURST_LENGTH);
  configWord = configWord << 16;
  
  HBConfig->hyperbus_cfg_word =  configWord;
  HBConfig->hyperbus_latency_1x = 0x04;
  HBConfig->hyperbus_latency_2x = 0x0A;
  value = HBConfig->hyperbus_cfg_word;
  
  neorv32_uart_printf("config word: %x\n", value);
  
  neorv32_uart_print("\nWishbone HyperRAM read/write test\n");
  
  int wordsToTest = 4;
  
  neorv32_uart_print("Read before\n");
  for(int i = 0; i < wordsToTest; ++i)
  {
    value = HyperRAMArray[i];
    neorv32_uart_printf("Data at 0x%x: 0x%x\n",i*4, value);
  }
  
  neorv32_uart_print("Write\n");
  for(int i = 0; i < wordsToTest; ++i)
  {
      HyperRAMArray[i] = (0xA5A5A500 + i);
      neorv32_uart_printf("Data written 0x%x: 0x%x\n",i*4, (0xA5A5A500 + i));
  }
  
  neorv32_uart_print("Read after\n");
  for(int i = 0; i < wordsToTest; ++i)
  {
    value = HyperRAMArray[i];
    neorv32_uart_printf("Data at 0x%x: 0x%x\n",i*4, value);
  }
  neorv32_uart_print("Done!\n");
  
  while (1) 
  {

  }

  return 0;
}
