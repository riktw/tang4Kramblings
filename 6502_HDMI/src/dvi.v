module display_dvi(
    input  wire CLK,                // board clock: 100 MHz on Arty/Basys3/Nexys
    input  wire RST_BTN,            // reset button
    output wire hdmi_tx_clk_n,      // HDMI clock differential negative
    output wire hdmi_tx_clk_p,      // HDMI clock differential positive
    output wire [2:0] hdmi_tx_n,    // Three HDMI channels differential negative
    output wire [2:0] hdmi_tx_p,    // Three HDMI channels differential positive

    input wire [7:0] red,
    input wire [7:0] green,
    input wire [7:0] blue,

    output wire dviclk,
    output wire framestart
    );

    // Display Clocks
    wire pix_clk;                   // pixel clock
    wire pix_clk_5x;                // 5x clock for 10:1 DDR SerDes
    wire clk_lock;                  // clock locked?

    Gowin_PLLVR clockpll(
        .clkin(CLK), //input clkin, 27Mhz
        .clkout(pix_clk_5x), //output clkout, 20Mhz
        .lock(clk_lock) //output lock
        
    );

    Gowin_CLKDIV clockdiv(
        .clkout(pix_clk), //output clkout
        .hclkin(pix_clk_5x), //input hclkin
        .resetn(clk_lock), //input resetn
        .calib(1'b1) //input calib
    );


    // Display Timings
    wire signed [15:0] sx;          // horizontal screen position (signed)
    wire signed [15:0] sy;          // vertical screen position (signed)
    wire h_sync;                    // horizontal sync
    wire v_sync;                    // vertical sync
    wire de;                        // display enable
    wire frame;                     // frame start

    display_timings #(              // 640x480  800x600 1280x720 1920x1080
        .H_RES(640),                //     640      800     1280      1920
        .V_RES(480),                //     480      600      720      1080
        .H_FP(16),                  //      16       40      110        88
        .H_SYNC(96),                //      96      128       40        44
        .H_BP(48),                  //      48       88      220       148
        .V_FP(10),                  //      10        1        5         4
        .V_SYNC(2),                 //       2        4        5         5
        .V_BP(33),                  //      33       23       20        36
        .H_POL(0),                  //       0        1        1         1
        .V_POL(0)                   //       0        1        1         1
    )
    display_timings_inst (
        .i_pix_clk(pix_clk),
        .i_rst(!clk_lock),
        .o_hs(h_sync),
        .o_vs(v_sync),
        .o_de(de),
        .o_frame(frame),
        .o_sx(sx),
        .o_sy(sy)
    );

    // TMDS Encoding and Serialization
    wire tmds_ch0_serial, tmds_ch1_serial, tmds_ch2_serial, tmds_chc_serial;
    dvi_generator dvi_out (
        .i_pix_clk(pix_clk),
        .i_pix_clk_5x(pix_clk_5x),
        .i_rst(!clk_lock),
        .i_de(de),
        .i_data_ch0(blue),
        .i_data_ch1(green),
        .i_data_ch2(red),
        .i_ctrl_ch0({v_sync, h_sync}),
        .i_ctrl_ch1(2'b00),
        .i_ctrl_ch2(2'b00),
        .o_tmds_ch0_serial(tmds_ch0_serial),
        .o_tmds_ch1_serial(tmds_ch1_serial),
        .o_tmds_ch2_serial(tmds_ch2_serial),
        .o_tmds_chc_serial(tmds_chc_serial)  // encode pixel clock via same path
    );

    // TMDS Buffered Output
    TLVDS_OBUF OBUFDS_red  (.I(tmds_ch2_serial), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    TLVDS_OBUF OBUFDS_green(.I(tmds_ch1_serial), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    TLVDS_OBUF OBUFDS_blue (.I(tmds_ch0_serial), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    TLVDS_OBUF OBUFDS_clock(.I(tmds_chc_serial), .O(hdmi_tx_clk_p), .OB(hdmi_tx_clk_n));

    assign dviclk = pix_clk;
    assign framestart = frame;

endmodule