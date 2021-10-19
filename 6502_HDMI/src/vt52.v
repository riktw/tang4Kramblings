module vt52 (input  wire     clk,
            input wire start,
            output wire hsync,
            output wire vsync,
            output wire video,
            output wire led,
            input  wire     ps2_data,
            input  wire     ps2_clk,
            input  wire     rxd,
            output wire     txd
            );
   localparam ROWS = 25;
   localparam COLS = 80;
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // clock generator outputs
   wire clk_usb, reset_usb;
   wire clk_vga, reset_vga;
   wire hs_clk;

   // scroll
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [ADDR_BITS-1:0] first_char;
   // cursor
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   // char buffer
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [ADDR_BITS-1:0] char_address;
   wire [7:0] char;
   // char rom
   wire [11:0] char_rom_address;
   wire [7:0] char_rom_data;

   // video generator
   wire vblank, hblank;

   // uart input/output
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;

   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;

   // led follows the cursor blink
   assign led = cursor_blink_on;

   //
   // Instantiate all modules
   //
   clock_generator clock_generator(.clk(clk),
                                   .clk_usb(clk_usb),
                                   .reset_usb(reset_usb),
                                   .clk_vga(clk_vga),
                                   .reset_vga(reset_vga)
                                   );

   keyboard keyboard(.clk(clk),
                     .reset(reset_usb),
                     .ps2_data(ps2_data),
                     .ps2_clk(ps2_clk),
                     .data(uart_in_data),
                     .valid(uart_in_valid),
                     .ready(uart_in_ready)
                     );

   cursor #(.ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS))
      cursor(.clk(clk),
             .reset(reset_usb),
             .tick(vblank),
             .x(cursor_x),
             .y(cursor_y),
             .blink_on(cursor_blink_on),
             .new_x(new_cursor_x),
             .new_y(new_cursor_y),
             .wen(new_cursor_wen)
            );

   simple_register #(.SIZE(ADDR_BITS))
      scroll_register(.clk(clk),
                      .reset(reset_usb),
                      .idata(new_first_char),
                      .wen(new_first_char_wen),
                      .odata(first_char)
                      );

   char_buffer char_buffer(.clk(clk),
                           .din(new_char),
                           .waddr(new_char_address),
                           .wen(new_char_wen),
                           .raddr(char_address),
                           .dout(char)
                           );

   char_rom char_rom(.clk(clk),
                     .addr(char_rom_address),
                     .dout(char_rom_data)
                     );

   video_generator video_generator(.clk(clk_vga),
                      .reset(reset_vga),
                      .start(start),
                      .hsync(hsync),
                      .vsync(vsync),
                      .video(video),
                      .hblank(hblank),
                      .vblank(vblank),
                      .cursor_x(cursor_x),
                      .cursor_y(cursor_y),
                      .cursor_blink_on(cursor_blink_on),
                      .first_char(first_char),
                      .char_buffer_address(char_address),
                      .char_buffer_data(char),
                      .char_rom_address(char_rom_address),
                      .char_rom_data(char_rom_data)
                      );

   uart uart(.clk(clk),
                 .rst(reset_usb),
                 // usb pins
                 .rxd(rxd),
                 .txd(txd),
                 // uart pipeline in (keyboard->usb)
                 .s_axis_tdata(uart_in_data),
                 .s_axis_tvalid(uart_in_valid),
                 .s_axis_tready(uart_in_ready),
                 // uart pipeline out (usb->command_handler)
                 .m_axis_tdata(uart_out_data),
                 .m_axis_tvalid(uart_out_valid),
                 .m_axis_tready(uart_out_ready),
                     // status
                .tx_busy(),
                .rx_busy(),
                .rx_overrun_error(),
                .rx_frame_error(),
                //config
                 .prescale(50400000/(115200*8))
                 );

   command_handler #(.ROWS(ROWS),
                     .COLS(COLS),
                     .ROW_BITS(ROW_BITS),
                     .COL_BITS(COL_BITS),
                     .ADDR_BITS(ADDR_BITS))
      command_handler(.clk(clk),
                      .reset(reset_usb),
                      .data(uart_out_data),
                      .valid(uart_out_valid),
                      .ready(uart_out_ready),
                      .new_first_char(new_first_char),
                      .new_first_char_wen(new_first_char_wen),
                      .new_char(new_char),
                      .new_char_address(new_char_address),
                      .new_char_wen(new_char_wen),
                      .new_cursor_x(new_cursor_x),
                      .new_cursor_y(new_cursor_y),
                      .new_cursor_wen(new_cursor_wen)
                      );

 endmodule
