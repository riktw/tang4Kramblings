`timescale 1ns / 1ps
`default_nettype none

// Project F: Display 10:1 Serializer
// (C)2019 Will Green, Open source hardware released under the MIT License
// Learn more at https://projectf.io

module serializer_10to1(
    input  wire i_clk,          // parallel clock
    input  wire i_clk_hs,       // high-speed clock (5 x i_clk when using DDR)
    input  wire i_rst_oserdes,  // reset from async reset (active high)
    input  wire [9:0] i_data,   // input parallel data
    output wire o_data          // output serial data
    );

    OSER10 tdms_ser_red( 
        .Q(o_data),   
        .D0(i_data[0]),   
        .D1(i_data[1]), 
        .D2(i_data[2]),   
        .D3(i_data[3]),   
        .D4(i_data[4]),   
        .D5(i_data[5]), 
        .D6(i_data[6]),   
        .D7(i_data[7]),   
        .D8(i_data[8]),   
        .D9(i_data[9]),   
        .PCLK(i_clk),   
        .FCLK(i_clk_hs), 
        .RESET(i_rst_oserdes) 
); 
defparam tdms_ser_red.GSREN="false"; 
defparam tdms_ser_red.LSREN ="true";

endmodule
